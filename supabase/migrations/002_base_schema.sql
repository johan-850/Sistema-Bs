-- ============================================================
-- Sistema Bs — Migración 002: Esquema base (products, cash_registers)
-- Ejecuta en Supabase SQL Editor, DESPUÉS de 001_auth_users.sql
-- (products.created_by y cash_registers.cashier_id referencian
-- public.profiles, creada en 001) y ANTES de 003 en adelante.
--
-- En Sistema AS estas dos tablas y este tipo se crearon a mano desde
-- el Dashboard y nunca quedaron en una migración — 004 en adelante ya
-- las referencian por FK como si existieran. Esta migración las
-- reconstruye a partir de las entidades Dart (Product, CashRegister),
-- sus datasources, y cada FK/columna que el resto de migraciones ya
-- asume. USB-001 (EPB-01).
-- ============================================================

-- ── Tipo: register_status ────────────────────────────────────
-- 'open' y 'closed' existían desde el inicio; 'closing' se agregó
-- después en 009_closing.sql (ahí sigue el ALTER TYPE ADD VALUE,
-- no se duplica aquí).
CREATE TYPE public.register_status AS ENUM ('open', 'closing', 'closed');

-- ── Tabla: products ───────────────────────────────────────────
CREATE TABLE public.products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barcode     TEXT UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  category    TEXT NOT NULL DEFAULT 'General',
  price       NUMERIC NOT NULL CHECK (price >= 0),
  cost_price  NUMERIC NOT NULL CHECK (cost_price >= 0),
  stock       INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  min_stock   INTEGER NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  unit        TEXT NOT NULL DEFAULT 'unidad',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  image_url   TEXT,
  supplier    TEXT,
  created_by  UUID REFERENCES public.profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.products IS 'Catálogo de productos — reconstruida (creada a mano en Sistema AS)';
COMMENT ON COLUMN public.products.barcode IS 'UNIQUE simple (no parcial): el chequeo de duplicados de la app no distingue activos de archivados';

CREATE INDEX idx_products_barcode   ON public.products(barcode);
CREATE INDEX idx_products_category  ON public.products(category);
CREATE INDEX idx_products_is_active ON public.products(is_active);

-- ── Tabla: cash_registers ─────────────────────────────────────
-- closing_notes y closing_summary NO van aquí: siguen agregándose
-- vía ALTER TABLE en 009_closing.sql, sin modificar ese archivo.
CREATE TABLE public.cash_registers (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashier_id         UUID NOT NULL REFERENCES public.profiles(id),
  opening_amount     NUMERIC NOT NULL CHECK (opening_amount >= 0),
  opening_breakdown  JSONB NOT NULL DEFAULT '{}',
  notes              TEXT,
  closing_amount     NUMERIC,
  closing_breakdown  JSONB,
  opening_time       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closing_time       TIMESTAMPTZ,
  status             public.register_status NOT NULL DEFAULT 'open',
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.cash_registers IS 'Turnos de caja (apertura → cierre) — reconstruida (creada a mano en Sistema AS)';

CREATE INDEX idx_cash_registers_cashier_id   ON public.cash_registers(cashier_id);
CREATE INDEX idx_cash_registers_status       ON public.cash_registers(status);
CREATE INDEX idx_cash_registers_opening_time ON public.cash_registers(opening_time DESC);

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE public.products      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_registers ENABLE ROW LEVEL SECURITY;

-- products: cualquier autenticado lee el catálogo (el cajero lo
-- necesita para vender); solo AdminMaster escribe.
DROP POLICY IF EXISTS "read_all_products" ON public.products;
CREATE POLICY "read_all_products"
  ON public.products FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "admin_write_products" ON public.products;
CREATE POLICY "admin_write_products"
  ON public.products FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

DROP POLICY IF EXISTS "admin_update_products" ON public.products;
CREATE POLICY "admin_update_products"
  ON public.products FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

DROP POLICY IF EXISTS "admin_delete_products" ON public.products;
CREATE POLICY "admin_delete_products"
  ON public.products FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

-- cash_registers: cada cajero ve y abre la suya, AdminMaster ve todas.
-- Sin policy de UPDATE: el cierre pasa por close_register() (009),
-- SECURITY DEFINER — no necesita permiso de fila.
DROP POLICY IF EXISTS "read_own_or_admin_cash_registers" ON public.cash_registers;
CREATE POLICY "read_own_or_admin_cash_registers"
  ON public.cash_registers FOR SELECT TO authenticated
  USING (
    cashier_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster')
  );

DROP POLICY IF EXISTS "cashier_opens_own_register" ON public.cash_registers;
CREATE POLICY "cashier_opens_own_register"
  ON public.cash_registers FOR INSERT TO authenticated
  WITH CHECK (cashier_id = auth.uid());

-- ── Realtime ──────────────────────────────────────────────────
-- En AS esto vivía solo en el Dashboard; queda versionado.
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
