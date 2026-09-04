// Supabase Edge Function: send-weekly-report
// Envía el reporte semanal de ventas por correo (US-054)
// Deploy: supabase functions deploy send-weekly-report
// Secretos requeridos: RESEND_API_KEY, REPORT_FROM_EMAIL (opcional,
// por defecto usa el dominio de pruebas de Resend)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const currencyFmt = (n: number) =>
  new Intl.NumberFormat("es-CO", { style: "currency", currency: "COP", maximumFractionDigits: 0 }).format(n);

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";
    // El cron (pg_cron/pg_net) llama con el service_role key como Bearer —
    // es un JWT válido del proyecto, no necesita verificación de usuario.
    const isTrustedCron = serviceRoleKey.length > 0 && authHeader === `Bearer ${serviceRoleKey}`;

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const body = await req.json().catch(() => ({}));
    let manual = body?.manual === true;

    if (!isTrustedCron) {
      // Llamada de un usuario real (botón "Enviar de prueba ahora") — exige adminmaster.
      if (!authHeader) throw new Error("No autorizado");
      const callerClient = createClient(
        supabaseUrl,
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        { global: { headers: { Authorization: authHeader } } },
      );
      const { data: { user: caller } } = await callerClient.auth.getUser();
      if (!caller) throw new Error("Token inválido");

      const callerProfile = await supabaseAdmin
        .from("profiles")
        .select("role")
        .eq("id", caller.id)
        .single();
      if (callerProfile.data?.role !== "adminmaster") {
        throw new Error("Solo el AdminMaster puede enviar el reporte");
      }
      manual = true; // un usuario autenticado siempre está probando manualmente
    }

    const { data: settings } = await supabaseAdmin
      .from("store_settings")
      .select("weekly_report_enabled, weekly_report_email")
      .eq("id", 1)
      .single();

    if (!manual && !settings?.weekly_report_enabled) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "Reporte desactivado" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
      );
    }

    const recipient = settings?.weekly_report_email as string | null;
    if (!recipient) {
      return new Response(
        JSON.stringify({ error: "No hay correo configurado para el reporte" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
      );
    }

    // ── Rango: semana actual (lunes → ahora) y semana anterior ──────
    const now = new Date();
    const day = now.getUTCDay(); // 0 = domingo
    const daysSinceMonday = day === 0 ? 6 : day - 1;
    const weekStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - daysSinceMonday));
    const weekPrevStart = new Date(weekStart.getTime() - 7 * 86400000);

    const sumSales = async (from: Date, to: Date) => {
      const { data } = await supabaseAdmin
        .from("sales")
        .select("total")
        .gte("created_at", from.toISOString())
        .lt("created_at", to.toISOString());
      const rows = data ?? [];
      const total = rows.reduce((s: number, r: { total: number }) => s + Number(r.total), 0);
      return { total, count: rows.length };
    };

    const [thisWeek, lastWeek] = await Promise.all([
      sumSales(weekStart, now),
      sumSales(weekPrevStart, weekStart),
    ]);

    // ── Top 5 productos de la semana ─────────────────────────────────
    const { data: saleIdRows } = await supabaseAdmin
      .from("sales")
      .select("id")
      .gte("created_at", weekStart.toISOString())
      .lt("created_at", now.toISOString());
    const saleIds = (saleIdRows ?? []).map((r: { id: string }) => r.id);

    let topProducts: { name: string; units: number; amount: number }[] = [];
    if (saleIds.length > 0) {
      const { data: itemRows } = await supabaseAdmin
        .from("sale_items")
        .select("product_name, quantity, subtotal")
        .in("sale_id", saleIds);
      const byProduct = new Map<string, { units: number; amount: number }>();
      for (const r of (itemRows ?? []) as { product_name: string; quantity: number; subtotal: number }[]) {
        const prev = byProduct.get(r.product_name) ?? { units: 0, amount: 0 };
        byProduct.set(r.product_name, {
          units: prev.units + Number(r.quantity),
          amount: prev.amount + Number(r.subtotal),
        });
      }
      topProducts = [...byProduct.entries()]
        .map(([name, v]) => ({ name, ...v }))
        .sort((a, b) => b.units - a.units)
        .slice(0, 5);
    }

    // ── Alertas de stock bajo ─────────────────────────────────────────
    const { data: productRows } = await supabaseAdmin
      .from("products")
      .select("name, stock, min_stock")
      .eq("is_active", true);
    const lowStock = ((productRows ?? []) as { name: string; stock: number; min_stock: number }[])
      .filter((p) => p.stock <= p.min_stock)
      .sort((a, b) => a.stock - b.stock)
      .slice(0, 10);

    // ── HTML del correo (estilos inline — los clientes de correo no
    // soportan CSS moderno ni hojas de estilo externas) ────────────
    const pctChange = lastWeek.total > 0
      ? `${thisWeek.total >= lastWeek.total ? "+" : ""}${(((thisWeek.total - lastWeek.total) / lastWeek.total) * 100).toFixed(0)}%`
      : "—";

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1f2328;">
        <h2 style="color:#00A87D; margin-bottom:4px;">Reporte semanal — Abarrotería Pro</h2>
        <p style="color:#57606a; font-size:13px; margin-top:0;">
          Semana del ${weekStart.toLocaleDateString("es-CO")} al ${now.toLocaleDateString("es-CO")}
        </p>

        <table width="100%" cellpadding="14" style="border-collapse:collapse; margin-bottom:24px;">
          <tr>
            <td style="background:#f6f8fa; border-radius:8px;">
              <strong style="font-size:22px;">${currencyFmt(thisWeek.total)}</strong><br/>
              <span style="color:#57606a; font-size:12px;">
                ${thisWeek.count} ventas · vs. semana anterior: ${pctChange}
              </span>
            </td>
          </tr>
        </table>

        <h3 style="margin-bottom:6px;">Top 5 productos</h3>
        <table width="100%" cellpadding="6" style="border-collapse:collapse; margin-bottom:20px;">
          ${topProducts.map((p) => `
            <tr style="border-bottom:1px solid #eaeef2;">
              <td>${p.name}</td>
              <td align="right">${p.units} u.</td>
              <td align="right">${currencyFmt(p.amount)}</td>
            </tr>`).join("") || "<tr><td>Sin ventas esta semana.</td></tr>"}
        </table>

        <h3 style="margin-bottom:6px;">Alertas de stock bajo</h3>
        <table width="100%" cellpadding="6" style="border-collapse:collapse;">
          ${lowStock.map((p) => `
            <tr style="border-bottom:1px solid #eaeef2;">
              <td>${p.name}</td>
              <td align="right" style="color:#cf222e;">${p.stock} / mín. ${p.min_stock}</td>
            </tr>`).join("") || "<tr><td>Sin alertas de stock.</td></tr>"}
        </table>
      </div>
    `;

    const resendResp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY") ?? ""}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: Deno.env.get("REPORT_FROM_EMAIL") ?? "onboarding@resend.dev",
        to: recipient,
        subject: `Reporte semanal — ${currencyFmt(thisWeek.total)} en ventas`,
        html,
      }),
    });

    if (!resendResp.ok) {
      const errText = await resendResp.text();
      throw new Error(`Resend respondió ${resendResp.status}: ${errText}`);
    }

    return new Response(
      JSON.stringify({ success: true, sentTo: recipient }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 },
    );
  }
});
