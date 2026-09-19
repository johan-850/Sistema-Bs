-- ============================================================
-- Sistema Bs — Migración 011: una sola caja sin cerrar por cajero
-- USB-039 (SB-03) — corrección heredada de Sistema AS
--
--   *** NO CORRAS ESTE ARCHIVO DE UNA. LEE EL PASO 1 PRIMERO. ***
--
-- El índice del paso 2 FALLA si ya existen cajas duplicadas. En una
-- base recién creada no debería haberlas, pero conviene confirmarlo
-- antes: si el sistema ya se usó, el bug de zona horaria pudo haberlas
-- generado.
-- ============================================================

-- ── Por qué existe esta migración ─────────────────────────────
-- 002_base_schema.sql reconstruyó cash_registers a partir de las
-- entidades Dart, fielmente — incluido el hueco: nada impedía que un
-- cajero tuviera dos cajas sin cerrar.
--
-- Eso, combinado con el filtro `opening_time >= hoy` calculado en UTC
-- (Colombia es UTC−5, así que la medianoche UTC son las 7 p.m.
-- locales), producía aperturas duplicadas: a las 7 p.m. la caja del
-- turno desaparecía del filtro, el cajero creía no tener turno abierto
-- y abría otra. El filtro ya se corrigió en la app; esto cierra la
-- puerta del lado de la base.

-- ── PASO 1: diagnóstico (corre solo esto primero) ─────────────
-- Muestra las cajas sin cerrar, con cuántas ventas y gastos cuelgan de
-- cada una. Si algún cajero aparece con más de una fila, hay que
-- resolverlo antes de seguir.
--
-- SELECT
--   p.name                        AS cajero,
--   cr.id,
--   cr.status,
--   cr.opening_time AT TIME ZONE 'America/Bogota' AS apertura_local,
--   cr.opening_amount,
--   (SELECT COUNT(*) FROM public.sales    s WHERE s.cash_register_id = cr.id) AS ventas,
--   (SELECT COUNT(*) FROM public.expenses e WHERE e.cash_register_id = cr.id) AS gastos,
--   COUNT(*) OVER (PARTITION BY cr.cashier_id) AS cajas_sin_cerrar_del_cajero
-- FROM public.cash_registers cr
-- JOIN public.profiles p ON p.id = cr.cashier_id
-- WHERE cr.status IN ('open', 'closing')
-- ORDER BY cajero, cr.opening_time;

-- ── Cómo resolver los duplicados, si los hay ──────────────────
-- NO borres filas: las ventas y los gastos apuntan a la caja por clave
-- foránea, así que borrarla rompería el historial y el arqueo de ese
-- turno dejaría de existir.
--
-- Para cada cajero deja UNA sola caja sin cerrar — normalmente la más
-- reciente, la que de verdad está usando. Las demás ciérralas:
--
--   a) Si tiene ventas o gastos, ciérrala desde la app: el asistente de
--      cierre calcula el cuadre real. Con el arreglo de esta versión la
--      app ya deja retomar una caja vieja o a medio cerrar.
--
--   b) Si está vacía (0 ventas y 0 gastos), fue una apertura fantasma
--      del bug y se puede cerrar a mano dejando constancia:
--
--      UPDATE public.cash_registers
--      SET status = 'closed',
--          closing_time = NOW(),
--          closing_amount = opening_amount,
--          closing_notes = 'Cerrada administrativamente: apertura duplicada por el bug del turno activo',
--          updated_at = NOW()
--      WHERE id = '<pega-el-id-aqui>';

-- ── PASO 2: el índice (solo cuando el paso 1 no muestre duplicados) ──
-- Esta es la garantía real: a partir de acá la base misma lo impide,
-- pase lo que pase en la app.
CREATE UNIQUE INDEX IF NOT EXISTS idx_cash_registers_one_open_per_cashier
  ON public.cash_registers (cashier_id)
  WHERE status IN ('open', 'closing');

COMMENT ON INDEX public.idx_cash_registers_one_open_per_cashier IS
  'Un cajero no puede tener dos cajas sin cerrar a la vez. Antes nada lo impedía y el filtro de fecha en UTC generaba aperturas duplicadas — USB-039';
