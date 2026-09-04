-- ============================================================
-- Sistema Bs — Migración 005: Ventas y cobro
-- Ejecuta en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Tabla: sales ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sales (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashier_id      UUID NOT NULL REFERENCES public.profiles(id),
  cash_register_id UUID NOT NULL REFERENCES public.cash_registers(id),
  total           NUMERIC NOT NULL CHECK (total >= 0),
  payment_method  TEXT NOT NULL CHECK (payment_method IN ('efectivo', 'transferencia', 'mixto')),
  cash_amount     NUMERIC,
  transfer_amount NUMERIC,
  change_amount   NUMERIC,
  status          TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.sales IS 'Ventas confirmadas del POS (US-030/US-031)';

CREATE INDEX IF NOT EXISTS idx_sales_cashier_id  ON public.sales(cashier_id);
CREATE INDEX IF NOT EXISTS idx_sales_created_at  ON public.sales(created_at DESC);

-- ── Tabla: sale_items ──────────────────────────────────────
-- product_name / unit_price quedan desnormalizados (snapshot del
-- momento de la venta): si el producto se edita o archiva después,
-- el recibo histórico no cambia. Mismo criterio que stock_movements.
CREATE TABLE IF NOT EXISTS public.sale_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id      UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id   UUID NOT NULL REFERENCES public.products(id),
  product_name TEXT NOT NULL,
  quantity     INTEGER NOT NULL CHECK (quantity > 0),
  unit_price   NUMERIC NOT NULL CHECK (unit_price >= 0),
  subtotal     NUMERIC NOT NULL CHECK (subtotal >= 0)
);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON public.sale_items(sale_id);

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE public.sales      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

-- Solo lectura desde el cliente: cada cajero ve sus propias ventas,
-- el AdminMaster las ve todas. No hay policy de INSERT a propósito
-- — la única forma de crear una venta es la función confirm_sale()
-- de abajo (SECURITY DEFINER), igual que adjust_product_stock en 003.
DROP POLICY IF EXISTS "read_own_or_admin_sales" ON public.sales;
CREATE POLICY "read_own_or_admin_sales"
  ON public.sales FOR SELECT TO authenticated
  USING (
    cashier_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

DROP POLICY IF EXISTS "read_own_or_admin_sale_items" ON public.sale_items;
CREATE POLICY "read_own_or_admin_sale_items"
  ON public.sale_items FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.sales
      WHERE sales.id = sale_items.sale_id
        AND (sales.cashier_id = auth.uid()
             OR EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster'))
    )
  );

-- ── Función: confirmar venta de forma atómica (US-030/US-031/US-032) ─
-- SECURITY DEFINER: valida adentro que quien llama sea el dueño de
-- una caja abierta, calcula el total server-side (nunca confía en el
-- total del cliente), verifica stock con FOR UPDATE (evita condición
-- de carrera si dos cajeros venden el último ítem a la vez), inserta
-- la venta + sus ítems, descuenta stock y registra el movimiento con
-- reason='venta' — el slot que quedó reservado para esto en 003.
--
-- No reutiliza adjust_product_stock(): esa función exige rol
-- adminmaster, y aquí quien cobra es el cajero.
CREATE OR REPLACE FUNCTION public.confirm_sale(
  p_cash_register_id UUID,
  p_payment_method   TEXT,
  p_cash_amount      NUMERIC,
  p_transfer_amount  NUMERIC,
  p_items            JSONB
)
RETURNS public.sales
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_cashier_id  UUID := auth.uid();
  v_total       NUMERIC := 0;
  v_change      NUMERIC := 0;
  v_sale        public.sales;
  v_item        JSONB;
  v_product_id  UUID;
  v_quantity    INTEGER;
  v_unit_price  NUMERIC;
  v_current_stock INTEGER;
BEGIN
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'La venta no tiene productos';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.cash_registers
    WHERE id = p_cash_register_id AND cashier_id = v_cashier_id AND status = 'open'
  ) THEN
    RAISE EXCEPTION 'No tienes una caja abierta válida para esta venta';
  END IF;

  -- Primera pasada: bloquear filas, validar stock y calcular el total.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_quantity   := (v_item->>'quantity')::INTEGER;
    v_unit_price := (v_item->>'unit_price')::NUMERIC;

    IF v_quantity <= 0 THEN
      RAISE EXCEPTION 'Cantidad inválida para %', v_item->>'product_name';
    END IF;

    SELECT stock INTO v_current_stock
    FROM public.products
    WHERE id = v_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Producto no encontrado: %', v_item->>'product_name';
    END IF;

    IF v_current_stock < v_quantity THEN
      RAISE EXCEPTION 'Stock insuficiente para "%" (disponible: %, solicitado: %)',
        v_item->>'product_name', v_current_stock, v_quantity;
    END IF;

    v_total := v_total + (v_quantity * v_unit_price);
  END LOOP;

  IF p_payment_method = 'efectivo' THEN
    IF p_cash_amount IS NULL OR p_cash_amount < v_total THEN
      RAISE EXCEPTION 'El monto recibido es menor al total de la venta';
    END IF;
    v_change := p_cash_amount - v_total;
  ELSIF p_payment_method = 'mixto' THEN
    IF abs(COALESCE(p_cash_amount, 0) + COALESCE(p_transfer_amount, 0) - v_total) > 1 THEN
      RAISE EXCEPTION 'La suma de efectivo y transferencia no coincide con el total';
    END IF;
  ELSIF p_payment_method != 'transferencia' THEN
    RAISE EXCEPTION 'Método de pago inválido: %', p_payment_method;
  END IF;

  INSERT INTO public.sales (
    cashier_id, cash_register_id, total, payment_method, cash_amount, transfer_amount, change_amount
  ) VALUES (
    v_cashier_id, p_cash_register_id, v_total, p_payment_method, p_cash_amount, p_transfer_amount, v_change
  )
  RETURNING * INTO v_sale;

  -- Segunda pasada: crear los ítems y descontar stock.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_quantity   := (v_item->>'quantity')::INTEGER;
    v_unit_price := (v_item->>'unit_price')::NUMERIC;

    INSERT INTO public.sale_items (sale_id, product_id, product_name, quantity, unit_price, subtotal)
    VALUES (v_sale.id, v_product_id, v_item->>'product_name', v_quantity, v_unit_price, v_quantity * v_unit_price);

    UPDATE public.products
    SET stock = stock - v_quantity, updated_at = NOW()
    WHERE id = v_product_id;

    INSERT INTO public.stock_movements (
      product_id, movement_type, reason, quantity, previous_stock, new_stock, notes, user_id
    )
    SELECT
      v_product_id, 'salida', 'venta', v_quantity,
      stock + v_quantity, stock,
      'Venta #' || v_sale.id, v_cashier_id
    FROM public.products WHERE id = v_product_id;
  END LOOP;

  RETURN v_sale;
END;
$$;
