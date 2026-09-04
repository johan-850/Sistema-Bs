-- ============================================================
-- Sistema Bs — Migración 009: Cierre de Caja
-- Ejecuta en Supabase SQL Editor (proyecto conectado)
-- ============================================================

-- ── Nuevo valor de enum: 'closing' ──────────────────────────
-- Bloquea nuevas ventas/gastos apenas el cajero inicia el cierre,
-- sin tocar confirm_sale ni la policy de expenses (ambas ya exigen
-- cash_registers.status = 'open').
ALTER TYPE public.register_status ADD VALUE IF NOT EXISTS 'closing';

-- ── cash_registers: columnas nuevas para el cuadre ──────────
ALTER TABLE public.cash_registers ADD COLUMN IF NOT EXISTS closing_notes TEXT;
ALTER TABLE public.cash_registers ADD COLUMN IF NOT EXISTS closing_summary JSONB;

COMMENT ON COLUMN public.cash_registers.closing_notes IS 'Comentario del cajero al cerrar (distinto de notes, que es de la apertura) — US-041';
COMMENT ON COLUMN public.cash_registers.closing_summary IS 'Documento de cuadre congelado al cerrar: ventas por método, gastos, efectivo esperado/contado, diferencia — US-042';

-- ── store_settings: umbral para exigir comentario de cierre ─
ALTER TABLE public.store_settings ADD COLUMN IF NOT EXISTS cash_diff_comment_threshold NUMERIC NOT NULL DEFAULT 5000;

-- ── Función: iniciar el cierre (US-039) ─────────────────────
-- Pasa la caja a 'closing'. A partir de ahí, confirm_sale() y la
-- policy insert_own_expense (ambas exigen status='open') bloquean
-- automáticamente nuevas ventas y gastos de esta caja.
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

  IF v_register.status != 'open' THEN
    RAISE EXCEPTION 'Esta caja ya no está abierta';
  END IF;

  UPDATE public.cash_registers
  SET status = 'closing', updated_at = NOW()
  WHERE id = p_register_id
  RETURNING * INTO v_register;

  RETURN v_register;
END;
$$;

-- ── Función: confirmar el cierre (US-040/US-041/US-042) ─────
-- Calcula todo server-side (nunca confía en totales del cliente,
-- mismo criterio que confirm_sale): ventas por método, efectivo que
-- realmente entró (efectivo puro + porción en efectivo de mixtas),
-- gastos, efectivo esperado y diferencia contra lo contado. Exige
-- comentario si la diferencia supera el umbral configurado.
CREATE OR REPLACE FUNCTION public.close_register(
  p_register_id        UUID,
  p_closing_breakdown  JSONB,
  p_closing_amount     NUMERIC,
  p_closing_notes      TEXT
)
RETURNS public.cash_registers
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_register          public.cash_registers;
  v_cash_sales        NUMERIC := 0;
  v_mixed_cash        NUMERIC := 0;
  v_transfer_sales    NUMERIC := 0;
  v_total_sales       NUMERIC := 0;
  v_transaction_count INTEGER := 0;
  v_total_expenses    NUMERIC := 0;
  v_cash_in           NUMERIC := 0;
  v_expected_cash     NUMERIC := 0;
  v_difference        NUMERIC := 0;
  v_threshold         NUMERIC := 5000;
  v_summary           JSONB;
BEGIN
  SELECT * INTO v_register
  FROM public.cash_registers
  WHERE id = p_register_id AND cashier_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Caja no encontrada';
  END IF;

  IF v_register.status NOT IN ('open', 'closing') THEN
    RAISE EXCEPTION 'Esta caja ya fue cerrada';
  END IF;

  IF p_closing_amount IS NULL OR p_closing_amount < 0 THEN
    RAISE EXCEPTION 'El monto contado no puede ser negativo';
  END IF;

  SELECT COALESCE(SUM(total), 0) INTO v_cash_sales
  FROM public.sales
  WHERE cash_register_id = p_register_id AND payment_method = 'efectivo';

  SELECT COALESCE(SUM(cash_amount), 0) INTO v_mixed_cash
  FROM public.sales
  WHERE cash_register_id = p_register_id AND payment_method = 'mixto';

  SELECT COALESCE(SUM(total), 0) INTO v_transfer_sales
  FROM public.sales
  WHERE cash_register_id = p_register_id AND payment_method = 'transferencia';

  SELECT COALESCE(SUM(total), 0), COUNT(*) INTO v_total_sales, v_transaction_count
  FROM public.sales
  WHERE cash_register_id = p_register_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
  FROM public.expenses
  WHERE cash_register_id = p_register_id;

  v_cash_in := v_cash_sales + v_mixed_cash;
  v_expected_cash := v_register.opening_amount + v_cash_in - v_total_expenses;
  v_difference := p_closing_amount - v_expected_cash;

  SELECT COALESCE(cash_diff_comment_threshold, 5000) INTO v_threshold
  FROM public.store_settings WHERE id = 1;

  IF abs(v_difference) > v_threshold AND (p_closing_notes IS NULL OR trim(p_closing_notes) = '') THEN
    RAISE EXCEPTION 'La diferencia de caja (%) supera el umbral permitido — agrega un comentario explicando la diferencia', v_difference;
  END IF;

  v_summary := jsonb_build_object(
    'opening_amount', v_register.opening_amount,
    'sales_efectivo', v_cash_sales,
    'sales_mixto_efectivo', v_mixed_cash,
    'sales_transferencia', v_transfer_sales,
    'sales_total', v_total_sales,
    'transaction_count', v_transaction_count,
    'total_expenses', v_total_expenses,
    'expected_cash', v_expected_cash,
    'counted_cash', p_closing_amount,
    'difference', v_difference
  );

  UPDATE public.cash_registers
  SET
    closing_amount = p_closing_amount,
    closing_breakdown = p_closing_breakdown,
    closing_summary = v_summary,
    closing_notes = p_closing_notes,
    closing_time = NOW(),
    status = 'closed',
    updated_at = NOW()
  WHERE id = p_register_id
  RETURNING * INTO v_register;

  RETURN v_register;
END;
$$;
