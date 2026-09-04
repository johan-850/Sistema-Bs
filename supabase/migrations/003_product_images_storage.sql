-- ============================================================
-- Sistema Bs — Migración 003: Storage de fotos de producto
-- Ejecutar en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Bucket público de imágenes de producto ────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- ── Row Level Security sobre storage.objects ──────────────────

-- Lectura pública (catálogo visible sin sesión, ej. imágenes en recibos)
CREATE POLICY "public_read_product_images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

-- Solo AdminMaster puede subir/actualizar/borrar fotos de producto.
-- Se valida contra public.profiles (la misma fuente de verdad que usa
-- toda la app para el rol) en vez de auth.jwt() -> app_metadata: ese claim
-- solo lo setea la Edge Function create-cashier para cajeros nuevos, no
-- existe para el AdminMaster inicial (se crea a mano en el Dashboard) y
-- además puede quedar desactualizado si el JWT no se refresca.
CREATE POLICY "admin_write_product_images"
  ON storage.objects FOR ALL TO authenticated
  USING (
    bucket_id = 'product-images'
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster'
    )
  )
  WITH CHECK (
    bucket_id = 'product-images'
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'adminmaster'
    )
  );
