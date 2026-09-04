-- ============================================================
-- Sistema Bs — Migración 010: Reporte Semanal por Correo (opcional)
-- Ejecuta en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── store_settings: configuración del reporte semanal (US-054) ─
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS weekly_report_enabled BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS weekly_report_email TEXT;

COMMENT ON COLUMN public.store_settings.weekly_report_enabled IS 'Si está activo, el cron semanal envía el reporte (el envío manual de prueba ignora este flag) — US-054';
COMMENT ON COLUMN public.store_settings.weekly_report_email IS 'Correo destino del reporte semanal — sin valor, ni el cron ni el envío manual pueden enviar nada';

-- ── Extensiones necesarias para programar el envío ──────────────
-- Si tu rol de base de datos no tiene privilegios para crear
-- extensiones (error de permisos), actívalas manualmente desde el
-- Dashboard de Supabase: Database → Extensions → busca "pg_cron" y
-- "pg_net" → Enable. Después vuelve a correr el resto de este archivo.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ── Cron: dispara la Edge Function todos los lunes 7:00 a.m. ────
-- Colombia es UTC-5 todo el año (sin horario de verano), por eso
-- '0 12 * * 1' (12:00 UTC, lunes) equivale a las 7:00 a.m. locales.
--
-- ⚠️ ANTES DE CORRER ESTE BLOQUE reemplaza los dos placeholders:
--   <PROJECT_REF>      → el ref de tu proyecto Supabase (Settings → General)
--   <SERVICE_ROLE_KEY>  → tu clave service_role (Settings → API) — NUNCA la
--                          subas a git; edítala solo en el SQL Editor.
-- El service_role key funciona como token de autorización porque es un
-- JWT válido del proyecto — mismo patrón que recomienda Supabase para
-- invocar Edge Functions desde pg_cron.
SELECT cron.schedule(
  'weekly-sales-report',
  '0 12 * * 1',
  $$
  SELECT net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-weekly-report',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <SERVICE_ROLE_KEY>',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
