-- ============================================================
-- Sistema Bs — Migración 001: Esquema base (auth y perfiles)
-- Ejecutar en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Extensiones ───────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Tabla: profiles (espejo de auth.users + datos extra) ─────
CREATE TABLE public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL DEFAULT '',
  role        TEXT NOT NULL DEFAULT 'cajero'
                CHECK (role IN ('adminmaster', 'cajero')),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  last_login  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  UUID REFERENCES public.profiles(id)
);

COMMENT ON TABLE public.profiles IS 'Perfiles de usuario vinculados a auth.users';
COMMENT ON COLUMN public.profiles.role IS 'adminmaster | cajero';

-- ── Tabla: user_activity_logs (auditoría US-004, US-006) ─────
CREATE TABLE public.user_activity_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES public.profiles(id),
  action       TEXT NOT NULL,  -- activated | deactivated | password_reset
  performed_by UUID REFERENCES public.profiles(id),
  metadata     JSONB NOT NULL DEFAULT '{}',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_activity_logs IS 'Auditoría de acciones sobre cuentas de cajero';

-- ── Índices de rendimiento ────────────────────────────────────
CREATE INDEX idx_profiles_role       ON public.profiles(role);
CREATE INDEX idx_profiles_is_active  ON public.profiles(is_active);
CREATE INDEX idx_profiles_created_at ON public.profiles(created_at DESC);
CREATE INDEX idx_activity_user_id    ON public.user_activity_logs(user_id);
CREATE INDEX idx_activity_created_at ON public.user_activity_logs(created_at DESC);

-- ── Trigger: crear perfil automáticamente al registrar usuario ─
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_app_meta_data->>'role', 'cajero')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ── Trigger: actualizar last_login en cada login exitoso ──────
CREATE OR REPLACE FUNCTION public.handle_user_login()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.last_sign_in_at IS DISTINCT FROM OLD.last_sign_in_at THEN
    UPDATE public.profiles
    SET last_login = NOW()
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_login
  AFTER UPDATE OF last_sign_in_at ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_user_login();

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_activity_logs ENABLE ROW LEVEL SECURITY;

-- Admins: acceso total a todos los perfiles
CREATE POLICY "admin_full_access_profiles"
  ON public.profiles FOR ALL TO authenticated
  USING (auth.jwt() -> 'app_metadata' ->> 'role' = 'adminmaster');

-- Cajeros: solo pueden leer su propio perfil
CREATE POLICY "cajero_read_own_profile"
  ON public.profiles FOR SELECT TO authenticated
  USING (auth.uid() = id);

-- Admins: acceso total al log
CREATE POLICY "admin_full_access_logs"
  ON public.user_activity_logs FOR ALL TO authenticated
  USING (auth.jwt() -> 'app_metadata' ->> 'role' = 'adminmaster');

-- ── Usuario AdminMaster inicial (ejecutar UNA vez) ────────────
-- NOTA: Crear el primer AM manualmente en Supabase Auth Dashboard,
-- luego ejecutar esto para asignarle el rol:
--
-- UPDATE public.profiles
-- SET role = 'adminmaster'
-- WHERE email = 'admin@tutienda.com';
--
-- También actualizar app_metadata via Supabase Dashboard > Auth > Users:
-- app_metadata: { "role": "adminmaster" }
