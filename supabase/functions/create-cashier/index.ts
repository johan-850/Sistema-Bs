// Supabase Edge Function: create-cashier
// Crea un usuario cajero usando el Admin API (service role)
// Deploy: supabase functions deploy create-cashier

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Solo AdminMaster puede llamar esta función
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("No autorizado");

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Verificar que quien llama es adminmaster
    const callerClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user: caller } } = await callerClient.auth.getUser();
    if (!caller) throw new Error("Token inválido");

    const callerProfile = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    if (callerProfile.data?.role !== "adminmaster") {
      throw new Error("Solo el AdminMaster puede crear cajeros");
    }

    // Crear el usuario cajero
    const { name, email, password } = await req.json();
    if (!name || !email || !password) throw new Error("Datos incompletos");

    const { data: newUser, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name },
      app_metadata: { role: "cajero" },
    });

    if (error) throw error;

    // Actualizar perfil con nombre y created_by
    await supabaseAdmin.from("profiles").update({
      name,
      role: "cajero",
      created_by: caller.id,
    }).eq("id", newUser.user!.id);

    return new Response(
      JSON.stringify({ success: true, userId: newUser.user!.id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 201 }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
    );
  }
});
