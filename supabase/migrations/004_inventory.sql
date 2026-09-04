-- ============================================================
-- Sistema Bs — Migración 004: Inventario y Stock
-- Ejecutar en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Tabla: stock_movements (US-021/US-022/US-023) ─────────────
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id     UUID NOT NULL REFERENCES public.products(id),
  movement_type  TEXT NOT NULL CHECK (movement_type IN ('entrada', 'salida')),
  reason         TEXT NOT NULL CHECK (reason IN ('venta', 'recepcion', 'merma', 'devolucion', 'ajuste')),
  quantity       INTEGER NOT NULL CHECK (quantity > 0),
  previous_stock INTEGER NOT NULL,
  new_stock      INTEGER NOT NULL,
  notes          TEXT,
  user_id        UUID REFERENCES public.profiles(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.stock_movements IS 'Auditoría de movimientos de stock (ajustes manuales y, a futuro, ventas)';
COMMENT ON COLUMN public.stock_movements.reason IS 'venta (reservado para EP-05) | recepcion | merma | devolucion | ajuste';

CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id  ON public.stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at  ON public.stock_movements(created_at DESC);

-- ── Tabla: restock_requests (US-024) ──────────────────────────
CREATE TABLE IF NOT EXISTS public.restock_requests (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   UUID NOT NULL REFERENCES public.products(id),
  requested_by UUID REFERENCES public.profiles(id),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes        TEXT,
  fulfilled    BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE public.restock_requests IS 'Marca de "pedido realizado" para productos bajo stock mínimo (US-024)';

CREATE INDEX IF NOT EXISTS idx_restock_requests_product_id ON public.restock_requests(product_id);

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE public.stock_movements  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restock_requests ENABLE ROW LEVEL SECURITY;

-- Solo AdminMaster gestiona inventario (EP-04 es 100% rol AM en el backlog).
-- Se valida contra public.profiles, no auth.jwt() -> app_metadata (ver migración 002).
-- DROP + CREATE para que la migración se pueda re-correr sin error si ya existía.
DROP POLICY IF EXISTS "admin_full_access_stock_movements" ON public.stock_movements;
CREATE POLICY "admin_full_access_stock_movements"
  ON public.stock_movements FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

DROP POLICY IF EXISTS "admin_full_access_restock_requests" ON public.restock_requests;
CREATE POLICY "admin_full_access_restock_requests"
  ON public.restock_requests FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

-- ── Función: ajuste atómico de stock (US-021, base para US-022) ─
-- SECURITY DEFINER: valida el rol adentro de la función y hace el
-- UPDATE + INSERT en una sola transacción implícita (atomicidad).
-- reason='venta' queda reservado para cuando EP-05 (POS) exista.
CREATE OR REPLACE FUNCTION public.adjust_product_stock(
  p_product_id    UUID,
  p_movement_type TEXT,
  p_reason        TEXT,
  p_quantity      INTEGER,
  p_notes         TEXT DEFAULT NULL
)
RETURNS public.stock_movements
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_current_stock INTEGER;
  v_new_stock     INTEGER;
  v_movement      public.stock_movements;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster'
  ) THEN
    RAISE EXCEPTION 'Solo el AdminMaster puede ajustar el stock';
  END IF;

  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser mayor a 0';
  END IF;

  SELECT stock INTO v_current_stock
  FROM public.products
  WHERE id = p_product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado';
  END IF;

  v_new_stock := CASE
    WHEN p_movement_type = 'entrada' THEN v_current_stock + p_quantity
    WHEN p_movement_type = 'salida'  THEN v_current_stock - p_quantity
    ELSE NULL
  END;

  IF v_new_stock IS NULL THEN
    RAISE EXCEPTION 'movement_type inválido: %', p_movement_type;
  END IF;

  IF v_new_stock < 0 THEN
    RAISE EXCEPTION 'El ajuste dejaría el stock en negativo (actual: %, solicitado: %)', v_current_stock, p_quantity;
  END IF;

  UPDATE public.products
  SET stock = v_new_stock, updated_at = NOW()
  WHERE id = p_product_id;

  INSERT INTO public.stock_movements (
    product_id, movement_type, reason, quantity, previous_stock, new_stock, notes, user_id
  ) VALUES (
    p_product_id, p_movement_type, p_reason, p_quantity, v_current_stock, v_new_stock, p_notes, auth.uid()
  )
  RETURNING * INTO v_movement;

  RETURN v_movement;
END;
$$;

-- ── Realtime para el dashboard de inventario (US-020) ─────────
-- Si 'products' ya estaba agregada a la publicación (ej. desde el
-- Dashboard), este bloque ignora el error de "ya es miembro".
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;
