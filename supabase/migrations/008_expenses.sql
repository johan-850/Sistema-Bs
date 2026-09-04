-- ============================================================
-- Sistema Bs — Migración 008: Gastos de Caja
-- Ejecuta en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Tabla: expense_categories (US-036) ─────────────────────
CREATE TABLE IF NOT EXISTS public.expense_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  icon        TEXT NOT NULL DEFAULT 'receipt_long',
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.expense_categories IS 'Categorías de gasto de caja configurables por el AdminMaster (US-036)';

INSERT INTO public.expense_categories (name, icon) VALUES
  ('Servicios', 'bolt_outlined'),
  ('Compras', 'shopping_cart_outlined'),
  ('Otros', 'more_horiz_rounded')
ON CONFLICT (name) DO NOTHING;

ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_expense_categories" ON public.expense_categories;
CREATE POLICY "read_expense_categories"
  ON public.expense_categories FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "admin_write_expense_categories" ON public.expense_categories;
CREATE POLICY "admin_write_expense_categories"
  ON public.expense_categories FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

-- ── profiles.expenses_enabled (US-038) ─────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS expenses_enabled BOOLEAN NOT NULL DEFAULT true;

-- ── store_settings: límite de gasto y ventana de edición ───
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS max_expense_amount NUMERIC;
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS expense_edit_window_minutes INTEGER NOT NULL DEFAULT 10;

-- ── Tabla: expenses (US-034/US-035) ────────────────────────
-- Registro de auditoría de egresos de caja — no requiere una función
-- SECURITY DEFINER como confirm_sale porque no hay stock ni otra tabla
-- que cuadrar atómicamente: un simple INSERT con RLS alcanza.
CREATE TABLE IF NOT EXISTS public.expenses (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashier_id        UUID NOT NULL DEFAULT auth.uid() REFERENCES public.profiles(id),
  cash_register_id  UUID NOT NULL REFERENCES public.cash_registers(id),
  category_id       UUID NOT NULL REFERENCES public.expense_categories(id),
  category_name     TEXT NOT NULL,
  amount            NUMERIC NOT NULL CHECK (amount > 0),
  description       TEXT NOT NULL DEFAULT '',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.expenses IS 'Gastos de caja registrados por el cajero durante su turno (US-034/US-035)';
COMMENT ON COLUMN public.expenses.category_name IS 'Snapshot del nombre de la categoría al momento del gasto — igual criterio que sale_items.product_name';

CREATE INDEX IF NOT EXISTS idx_expenses_cashier_id       ON public.expenses(cashier_id);
CREATE INDEX IF NOT EXISTS idx_expenses_cash_register_id ON public.expenses(cash_register_id);
CREATE INDEX IF NOT EXISTS idx_expenses_created_at       ON public.expenses(created_at DESC);

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- INSERT: el cajero debe ser dueño de la caja (abierta) que indica, y
-- tener el módulo de gastos habilitado en su perfil (US-038 exigido
-- también a nivel de base de datos, no solo ocultando el botón en la UI).
DROP POLICY IF EXISTS "insert_own_expense" ON public.expenses;
CREATE POLICY "insert_own_expense"
  ON public.expenses FOR INSERT TO authenticated
  WITH CHECK (
    cashier_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.cash_registers
      WHERE cash_registers.id = expenses.cash_register_id
        AND cash_registers.cashier_id = auth.uid()
        AND cash_registers.status = 'open'
    )
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.expenses_enabled = true
    )
  );

-- SELECT: propio o AdminMaster.
DROP POLICY IF EXISTS "read_own_or_admin_expenses" ON public.expenses;
CREATE POLICY "read_own_or_admin_expenses"
  ON public.expenses FOR SELECT TO authenticated
  USING (
    cashier_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

-- UPDATE: propio y solo dentro de la ventana de edición configurada
-- en store_settings (US-035 — "editable solo si fue hace < 10 min").
DROP POLICY IF EXISTS "update_own_recent_expense" ON public.expenses;
CREATE POLICY "update_own_recent_expense"
  ON public.expenses FOR UPDATE TO authenticated
  USING (
    cashier_id = auth.uid()
    AND created_at > NOW() - (
      (SELECT expense_edit_window_minutes FROM public.store_settings WHERE id = 1) * INTERVAL '1 minute'
    )
  )
  WITH CHECK (cashier_id = auth.uid());
