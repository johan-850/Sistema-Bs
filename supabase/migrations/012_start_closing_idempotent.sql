-- ============================================================
-- Sistema Bs — Migración 012: iniciar el cierre es idempotente
-- USB-039 (SB-03) — complementa el arreglo del cierre a medias
-- ============================================================

-- No es opcional: sin esto, el arreglo del cierre a medias de esta
-- misma versión queda a medio camino.
--
-- La app ahora detecta una caja en 'closing' y ofrece retomar el
-- cierre. Pero al confirmar, confirmStart() vuelve a llamar a
-- start_register_closing(), y la versión de la migración 009 exigía
-- status = 'open' y lanzaba 'Esta caja ya no está abierta' con
-- cualquier otra cosa. O sea: el cajero podía entrar a retomar el
-- cierre, pero no terminarlo.
--
-- El mismo callejón aparece sin retomar nada: si el UPDATE se confirma
-- pero la respuesta no llega al navegador —cosa normal con mala señal
-- en una tienda— el cajero reintenta y recibe ese error para siempre,
-- porque la caja ya quedó en 'closing'.
--
-- Pedir "inicia el cierre" sobre una caja que ya se está cerrando no es
-- un error: el estado que se pide ya es el que hay. Se devuelve la caja
-- tal cual y el cajero sigue al conteo.
--
-- Cerrada sí sigue siendo error: ahí ya no hay cuadre que hacer.
--
-- Misma firma que la 009, así que reemplaza — no crea una sobrecarga.
CREATE OR REPLACE FUNCTION public.start_register_closing(p_register_id UUID)
RETURNS public.cash_registers
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_register public.cash_registers;
BEGIN
  SELECT * INTO v_register
  FROM public.cash_registers
  WHERE id = p_register_id AND cashier_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Caja no encontrada';
  END IF;

  -- Ya estaba cerrándose: no hay nada que cambiar, se devuelve igual.
  IF v_register.status = 'closing' THEN
    RETURN v_register;
  END IF;

  IF v_register.status != 'open' THEN
    RAISE EXCEPTION 'Esta caja ya fue cerrada';
  END IF;

  UPDATE public.cash_registers
  SET status = 'closing', updated_at = NOW()
  WHERE id = p_register_id
  RETURNING * INTO v_register;

  RETURN v_register;
END;
$$;

COMMENT ON FUNCTION public.start_register_closing(UUID) IS
  'Pasa la caja a closing y bloquea ventas y gastos. Idempotente: sobre una caja ya en closing devuelve la fila sin tocarla, para que una respuesta perdida o un cierre retomado no dejen al cajero sin poder cuadrar — USB-039';
