// push-washington: poll congress activity, and on new activity send a
// SILENT (content-available) APNs push to every registered device. The
// push carries only a category + deep link; the phone's on-device brain
// decides whether to surface anything. No notification text server-side.
//
// Invoked by pg_cron (every ~15 min) with the service key. Also accepts a
// manual POST for testing. Secrets (function env, set in the dashboard):
//   APNS_KEY_P8      the .p8 contents (BEGIN PRIVATE KEY ... END)
//   APNS_KEY_ID      RLCNU9A7Y7
//   APNS_TEAM_ID     H66L66AQK8
//   APNS_TOPIC       io.politiface.politiface   (the app bundle id)
//   APNS_ENV         production | sandbox        (default production)
//   SB_SECRET_KEY / SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SERVICE_KEY = Deno.env.get("SB_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(SUPABASE_URL, SERVICE_KEY);

const APNS_HOST = (Deno.env.get("APNS_ENV") ?? "production") === "sandbox"
  ? "https://api.sandbox.push.apple.com"
  : "https://api.push.apple.com";

// ── APNs provider JWT (ES256 over the .p8), cached ~50 min ──────────────────
let cachedJwt: { token: string; at: number } | null = null;

function pemToArrayBuffer(pem: string): ArrayBuffer {
  // Bulletproof against however the .p8 survived the dashboard paste:
  // drop the BEGIN/END armor and any escaped newlines, then keep only
  // real base64 characters so a stray \n literal or quote cannot break
  // atob.
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\\n/g, "")
    .replace(/[^A-Za-z0-9+/=]/g, "");
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

function b64url(bytes: Uint8Array): string {
  let s = btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function providerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.at < 3000) return cachedJwt.token;

  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const header = b64url(
    new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })),
  );
  const claims = b64url(
    new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: now })),
  );
  const signingInput = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(Deno.env.get("APNS_KEY_P8")!),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  const token = `${signingInput}.${b64url(sig)}`;
  cachedJwt = { token, at: now };
  return token;
}

// ── send one silent push ────────────────────────────────────────────────────
async function sendSilent(
  jwt: string,
  token: string,
  category: string,
): Promise<number> {
  const topic = Deno.env.get("APNS_TOPIC") ?? "io.politiface.politiface";
  const res = await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "background",
      "apns-priority": "5",
    },
    // content-available wakes the app for a background check; no alert.
    body: JSON.stringify({
      aps: { "content-available": 1 },
      category,
      route: "/pulse",
    }),
  });
  return res.status; // 200 ok; 410 = token gone (prune); 400/403 = config
}

// ── detect new Washington activity ──────────────────────────────────────────

type PulseBill = {
  bill?: string;
  action_date?: string | null;
  action?: string | null;
};

// Same classifier as the app's WashingtonWatchService/Pulse feed: an
// enacted bill is a law. The pulse function returns ONLY { fetched_at,
// bills }; laws must be derived here, not read from fields it never sends.
function isEnactedLaw(b: PulseBill): boolean {
  return (b.action ?? "").toLowerCase().includes("became public law");
}

// Newest executive order number, straight from the Federal Register
// (keyless, public). The pulse function does not serve EOs (the app reads
// the Federal Register directly), so the watermark needs its own lookup.
// Fails soft to null: an FR hiccup must not block bill/law detection.
async function latestEoNumber(): Promise<number | null> {
  try {
    const res = await fetch(
      "https://www.federalregister.gov/api/v1/documents.json" +
        "?conditions%5Btype%5D%5B%5D=PRESDOCU" +
        "&conditions%5Bpresidential_document_type%5D%5B%5D=executive_order" +
        "&per_page=1&order=newest&fields%5B%5D=executive_order_number",
    );
    if (!res.ok) return null;
    const data = await res.json();
    const n = Number(data.results?.[0]?.executive_order_number);
    return Number.isFinite(n) && n > 0 ? n : null;
  } catch (_) {
    return null;
  }
}

async function pollForNews(): Promise<boolean> {
  const { data: sig } = await admin.schema("app").from("push_signal")
    .select("*").eq("id", true).single();

  // Reuse the pulse function's own live layer via its HTTP endpoint so
  // the API key stays in one place.
  const pulseRes = await fetch(`${SUPABASE_URL}/functions/v1/pulse`, {
    headers: { "authorization": `Bearer ${SERVICE_KEY}` },
  });
  if (!pulseRes.ok) return false;
  const pulse = await pulseRes.json();

  const bills = (pulse.bills ?? []) as PulseBill[];
  const laws = bills.filter(isEnactedLaw);
  // Law identity includes the action date so a re-observed old law does
  // not flap the watermark, and a genuinely new law always changes it.
  const latestLaw: string | null = laws
    .map((l) => `${l.bill}:${l.action_date ?? ""}`)
    .sort()
    .pop() ?? null;
  const latestBillDate: string | null = bills[0]?.action_date ?? null;
  const latestEo: number | null = await latestEoNumber();

  const changed = (latestEo != null && latestEo !== sig?.last_eo_number) ||
    (latestBillDate != null && latestBillDate !== sig?.last_bill_date) ||
    (latestLaw != null && latestLaw !== sig?.last_law);

  await admin.schema("app").from("push_signal").update({
    last_eo_number: latestEo ?? sig?.last_eo_number,
    last_bill_date: latestBillDate ?? sig?.last_bill_date,
    last_law: latestLaw ?? sig?.last_law,
    updated_at: new Date().toISOString(),
  }).eq("id", true);

  // First ever run (all watermarks null) baselines silently.
  const firstRun = sig?.last_eo_number == null && sig?.last_law == null &&
    sig?.last_bill_date == null;
  return changed && !firstRun;
}

async function allTokens(): Promise<{ token: string }[]> {
  const out: { token: string }[] = [];
  const page = 1000;
  for (let from = 0;; from += page) {
    const { data } = await admin.from("push_tokens")
      .select("token").eq("platform", "ios").range(from, from + page - 1);
    if (!data?.length) break;
    out.push(...data);
    if (data.length < page) break;
  }
  return out;
}

Deno.serve(async (req) => {
  // Cron/service-only: verify_jwt merely requires ANY valid JWT (the public
  // anon key qualifies), so a shared secret gates the fan-out. pg_cron and
  // manual ops pass X-Cron-Secret; without it, refuse.
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (cronSecret && req.headers.get("X-Cron-Secret") !== cronSecret) {
    return new Response("forbidden", { status: 403 });
  }
  const force = req.method === "POST" &&
    new URL(req.url).searchParams.get("force") === "1";
  const hasNews = force || await pollForNews();
  if (!hasNews) {
    return Response.json({ sent: 0, reason: "no new activity" });
  }

  const tokens = await allTokens();
  if (!tokens.length) return Response.json({ sent: 0, reason: "no tokens" });

  const jwt = await providerToken();
  let sent = 0;
  const dead: string[] = [];
  for (const row of tokens) {
    try {
      const status = await sendSilent(jwt, row.token, "washington");
      if (status === 200) sent++;
      else if (status === 410) dead.push(row.token);
    } catch (_) { /* transient; next cron pass retries */ }
  }
  if (dead.length) {
    await admin.from("push_tokens").delete().in("token", dead);
  }
  return Response.json({ sent, pruned: dead.length });
});
