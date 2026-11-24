// Garage: invia le notifiche push delle scadenze (7 giorni prima).
// Chiamato ogni mattina dal controllo automatico (pg_cron) con l'intestazione x-cron-secret,
// oppure dall'app con { test: true } per una notifica di prova al solo utente collegato.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const { data: cfg, error: cfgErr } = await db.rpc("push_config");
  if (cfgErr || !cfg) return json({ error: "configurazione mancante" }, 500);
  webpush.setVapidDetails("mailto:sebastianipao@gmail.com", cfg.vapid_public, cfg.vapid_private);

  const body = await req.json().catch(() => ({}));
  let subs: { endpoint: string; sub: webpush.PushSubscription }[] = [];
  let payload: Record<string, unknown>;

  if (body.test) {
    const jwt = (req.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: u } = await db.auth.getUser(jwt);
    if (!u?.user) return json({ error: "non autorizzato" }, 401);
    const r = await db.rpc("push_iscrizioni", { uid: u.user.id });
    subs = r.data || [];
    payload = { title: "Garage", body: "Notifiche attive: ti avviserò 7 giorni prima di ogni scadenza.", tag: "garage-test" };
  } else {
    if (req.headers.get("x-cron-secret") !== cfg.cron_secret) return json({ error: "non autorizzato" }, 401);
    const giorni = Number(body.giorni ?? 7);
    const { data: scad, error } = await db.rpc("push_scadenze", { giorni });
    if (error) return json({ error: error.message }, 500);
    if (!scad?.length) return json({ inviate: 0, scadenze: 0 });
    const r = await db.rpc("push_iscrizioni", { uid: null });
    subs = r.data || [];
    const righe = scad.map((s: { tipo: string; moto: string }) => `${s.tipo} – ${s.moto}`);
    payload = {
      title: scad.length === 1 ? `${scad[0].tipo} tra ${giorni} giorni` : `${scad.length} scadenze tra ${giorni} giorni`,
      body: righe.slice(0, 6).join("\n") + (righe.length > 6 ? `\n…e altre ${righe.length - 6}` : ""),
      tag: `garage-${new Date().toISOString().slice(0, 10)}`,
    };
    if (body.dryRun) return json({ inviate: 0, scadenze: scad.length, dispositivi: subs.length, payload });
  }

  let inviate = 0, rimosse = 0;
  await Promise.all(subs.map(async (s) => {
    try { await webpush.sendNotification(s.sub, JSON.stringify(payload), { TTL: 86400 }); inviate++; }
    catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) { await db.rpc("push_rimuovi_endpoint", { e: s.endpoint }); rimosse++; }
    }
  }));
  return json({ inviate, rimosse, dispositivi: subs.length });
});
