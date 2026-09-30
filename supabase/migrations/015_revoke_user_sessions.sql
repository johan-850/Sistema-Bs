-- ============================================================
-- Sistema Bs — Migración 015: cerrar las sesiones de un cajero
-- desactivado (US-004)
--
-- Reemplaza a la Edge Function toggle-cashier-status, que no validaba
-- quién la llamaba y le pasaba un user id a auth.admin.signOut(), que
-- espera el token de una sesión: nunca cerraba nada.
--
-- Borrar las filas de auth.sessions borra en cascada sus refresh
-- tokens: la app del cajero no puede renovar la sesión y lo saca en la
-- siguiente renovación (el access token vigente dura hasta 1 hora). El
-- login ya lo bloquea profiles.is_active.
-- ============================================================

CREATE OR REPLACE FUNCTION public.revoke_user_sessions(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_adminmaster() THEN
    RAISE EXCEPTION 'Solo el AdminMaster puede cerrar sesiones de otros usuarios'
      USING ERRCODE = '42501';
  END IF;

  DELETE FROM auth.sessions WHERE user_id = p_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.revoke_user_sessions(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_user_sessions(UUID) TO authenticated;
