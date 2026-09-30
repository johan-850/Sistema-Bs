-- ============================================================
-- Sistema Bs — Migración 014: el rol de admin sale de profiles
--
-- Las policies de profiles y user_activity_logs (001) validaban al
-- AdminMaster con auth.jwt() -> app_metadata ->> 'role'. Ese claim no
-- existe para el AdminMaster inicial (bootstrap_admin.sql solo cambia
-- profiles.role), así que el admin solo veía su propio perfil: la
-- lista de cajeros salía vacía y activar/desactivar no tocaba filas.
-- El resto del esquema (002 en adelante) ya valida contra profiles.
--
-- En profiles no se puede usar EXISTS (SELECT ... FROM profiles)
-- dentro de su propia policy (recursión infinita); por eso la consulta
-- va en una función SECURITY DEFINER, que no pasa por RLS.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_adminmaster()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'adminmaster'
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_adminmaster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_adminmaster() TO authenticated;

DROP POLICY IF EXISTS "admin_full_access_profiles" ON public.profiles;
CREATE POLICY "admin_full_access_profiles"
  ON public.profiles FOR ALL TO authenticated
  USING (public.is_adminmaster())
  WITH CHECK (public.is_adminmaster());

DROP POLICY IF EXISTS "admin_full_access_logs" ON public.user_activity_logs;
CREATE POLICY "admin_full_access_logs"
  ON public.user_activity_logs FOR ALL TO authenticated
  USING (public.is_adminmaster())
  WITH CHECK (public.is_adminmaster());

-- Verificación: entrando como AdminMaster en la app, la lista de
-- cajeros muestra a todos. Desde el SQL Editor (sin sesión) la función
-- devuelve false, es lo esperado:
--   SELECT public.is_adminmaster();
