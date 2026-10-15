// Cancellazione definitiva dell'account di chi chiama. Gira con la service_role (iniettata da Supabase):
// il browser non la vede mai. Body: { confirm } = l'email dell'account, scritta a mano dalla persona.
// Risposta: 200 { result: 'deleted' }; 400 confirm_mismatch; 401 unauthorized.
//
// Ordine: prima prepare_account_deletion (esercizi usati ritirati, sedute registrate cancellate), poi si
// elimina l'utente di Auth, che porta con sé profilo, collegamenti, piano, marchio e mesocicli dove la
// persona è l'atleta. Vedi la migrazione 20261015150100.
import { createClient } from "npm:@supabase/supabase-js@2";
import { z } from "npm:zod@4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const body = z.object({ confirm: z.string().trim().toLowerCase() });

const reply = (status: number, payload: Record<string, unknown>) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: {
      headers: { Authorization: req.headers.get("Authorization") ?? "" },
    },
  });
  // Si cancella solo l'account dell'utente del JWT: mai un id preso dal body.
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "unauthorized" });
  const { id, email } = userData.user;

  const parsed = body.safeParse(await req.json().catch(() => null));
  if (
    !parsed.success ||
    !email ||
    parsed.data.confirm !== email.trim().toLowerCase()
  ) {
    return reply(400, { error: "confirm_mismatch" });
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { error: prepareError } = await admin.rpc("prepare_account_deletion", {
    p_user_id: id,
  });
  if (prepareError) return reply(500, { error: "prepare_failed" });
  const { error: deleteError } = await admin.auth.admin.deleteUser(id);
  if (deleteError) return reply(500, { error: "delete_failed" });
  return reply(200, { result: "deleted" });
});
