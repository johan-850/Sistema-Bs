-- ============================================================
-- Sistema Bs — Migración 006: cancelaciones y alertas de stock
-- Log de venta cancelada y alerta de stock bajo
-- Ejecuta en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Tabla: sale_cancellations ──────────────────────────────
-- US-032: registro de auditoría cuando el cajero cancela/vacía
-- el carrito antes de confirmar el cobro. No hay reversión de
-- stock que hacer acá — nada se descontó todavía (eso solo pasa
-- dentro de confirm_sale), así que un simple INSERT alcanza: no
-- hace falta una función SECURITY DEFINER como con las ventas.
CREATE TABLE IF NOT EXISTS public.sale_cancellations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashier_id        UUID NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id),
  cash_register_id  UUID NOT NULL REFERENCES public.cash_registers(id),
  items_count       INTEGER NOT NULL CHECK (items_count > 0),
  total_amount      NUMERIC NOT NULL CHECK (total_amount >= 0),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.sale_cancellations IS 'Auditoría de carritos cancelados antes de cobrar (US-032)';

CREATE INDEX IF NOT EXISTS idx_sale_cancellations_cashier_id ON public.sale_cancellations(cashier_id);

ALTER TABLE public.sale_cancellations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "insert_own_sale_cancellations" ON public.sale_cancellations;
CREATE POLICY "insert_own_sale_cancellations"
  ON public.sale_cancellations FOR INSERT TO authenticated
  WITH CHECK (cashier_id = auth.uid());

DROP POLICY IF EXISTS "read_own_or_admin_sale_cancellations" ON public.sale_cancellations;
CREATE POLICY "read_own_or_admin_sale_cancellations"
  ON public.sale_cancellations FOR SELECT TO authenticated
  USING (
    cashier_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

-- ── Tabla: low_stock_alerts ────────────────────────────────
-- US-059: registro de auditoría cada vez que se agrega al carrito
-- un producto cuyo stock ya está en o por debajo del mínimo. No
-- bloquea la venta — es informativo, tanto en el banner como acá.
CREATE TABLE IF NOT EXISTS public.low_stock_alerts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashier_id      UUID NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id),
  product_id      UUID NOT NULL REFERENCES public.products(id),
  product_name    TEXT NOT NULL,
  stock_at_alert  INTEGER NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.low_stock_alerts IS 'Auditoría de alertas de stock bajo mostradas en el POS (US-059)';

CREATE INDEX IF NOT EXISTS idx_low_stock_alerts_product_id ON public.low_stock_alerts(product_id);

ALTER TABLE public.low_stock_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "insert_own_low_stock_alerts" ON public.low_stock_alerts;
CREATE POLICY "insert_own_low_stock_alerts"
  ON public.low_stock_alerts FOR INSERT TO authenticated
  WITH CHECK (cashier_id = auth.uid());

DROP POLICY IF EXISTS "read_own_or_admin_low_stock_alerts" ON public.low_stock_alerts;
CREATE POLICY "read_own_or_admin_low_stock_alerts"
  ON public.low_stock_alerts FOR SELECT TO authenticated
  USING (
    cashier_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );
