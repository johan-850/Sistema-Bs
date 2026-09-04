-- ============================================================
-- Sistema Bs — Bootstrap del AdminMaster inicial (USB-003)
--
-- No es una migración de esquema: es un paso operativo de una sola
-- vez. En Sistema AS este usuario se creó a mano en el Dashboard sin
-- dejar rastro documentado; aquí queda como procedimiento repetible.
--
-- Requisito previo: el trigger handle_new_user() de 001_auth_users.sql
-- ya crea una fila en profiles con role='cajero' apenas alguien se
-- registra en Auth — este script solo la asciende a 'adminmaster'.
--
-- Pasos:
--   1. Dashboard -> Authentication -> Add user -> crea el usuario con
--      el correo y contraseña del AdminMaster. Confirma el correo
--      automáticamente si el Dashboard lo permite (evita el paso de
--      verificación por email para este primer usuario).
--   2. Reemplaza el correo del WHERE de abajo por el que usaste.
--   3. Corre este bloque en el SQL Editor.
--   4. Verifica el resultado: debe devolver exactamente 1 fila con
--      role = 'adminmaster'.
-- ============================================================

UPDATE public.profiles
SET role = 'adminmaster'
WHERE email = 'admin@tudominio.com'  -- <-- reemplaza este correo
RETURNING id, email, name, role;
