-- ============================================================
-- Sistema Bs — Migración 007: QR de pago + foto de comprobante
-- Ejecuta en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Tabla: store_settings (singleton) ──────────────────────
-- Una sola fila (id fijo = 1) con configuración general del negocio.
-- Hoy solo guarda el QR de pago por transferencia; es el lugar natural
-- para futuras configuraciones globales (nombre del negocio, etc.).
CREATE TABLE IF NOT EXISTS public.store_settings (
  id            INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  qr_image_url  TEXT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.store_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;

-- Cualquier usuario autenticado (cajero incluido) necesita leerlo para
-- mostrar el QR al cobrar.
DROP POLICY IF EXISTS "read_store_settings" ON public.store_settings;
CREATE POLICY "read_store_settings"
  ON public.store_settings FOR SELECT TO authenticated
  USING (true);

-- Solo AdminMaster puede configurarlo.
DROP POLICY IF EXISTS "admin_write_store_settings" ON public.store_settings;
CREATE POLICY "admin_write_store_settings"
  ON public.store_settings FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

-- ── Bucket: store-assets (QR de pago, público) ─────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('store-assets', 'store-assets', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "public_read_store_assets" ON storage.objects;
CREATE POLICY "public_read_store_assets"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'store-assets');

DROP POLICY IF EXISTS "admin_write_store_assets" ON storage.objects;
CREATE POLICY "admin_write_store_assets"
  ON storage.objects FOR ALL TO authenticated
  USING (
    bucket_id = 'store-assets'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  )
  WITH CHECK (
    bucket_id = 'store-assets'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

-- ── Bucket: receipt-photos (foto del comprobante de transferencia) ─
-- Cualquier cajero autenticado sube/reemplaza su propia foto al cobrar
-- (no solo AdminMaster, a diferencia de product-images).
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipt-photos', 'receipt-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "public_read_receipt_photos" ON storage.objects;
CREATE POLICY "public_read_receipt_photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'receipt-photos');

DROP POLICY IF EXISTS "authenticated_write_receipt_photos" ON storage.objects;
CREATE POLICY "authenticated_write_receipt_photos"
  ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'receipt-photos')
  WITH CHECK (bucket_id = 'receipt-photos');

-- ── sales.receipt_photo_url ────────────────────────────────
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS receipt_photo_url TEXT;

-- ── confirm_sale: nuevo parámetro opcional p_receipt_photo_url ─
-- CREATE OR REPLACE con la firma completa (Postgres exige repetir
-- todos los parámetros, no solo el nuevo). El nuevo parámetro tiene
-- DEFAULT NULL, así que sigue siendo compatible con cualquier llamada
-- vieja que no lo mande.
CREATE OR REPLACE FUNCTION public.confirm_sale(
  p_cash_register_id   UUID,
  p_payment_method     TEXT,
  p_cash_amount        NUMERIC,
  p_transfer_amount    NUMERIC,
  p_items              JSONB,
  p_receipt_photo_url  TEXT DEFAULT NULL
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
    cashier_id, cash_register_id, total, payment_method, cash_amount, transfer_amount, change_amount,
    receipt_photo_url
  ) VALUES (
    v_cashier_id, p_cash_register_id, v_total, p_payment_method, p_cash_amount, p_transfer_amount, v_change,
    p_receipt_photo_url
  )
  RETURNING * INTO v_sale;

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
