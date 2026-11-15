// push-washington: poll Washington activity every ~15 minutes and notify.
//
// Two tiers of news:
//   * White House presidential actions (whitehouse.gov RSS): same-day
//     signal. A new action sends a VISIBLE alert push (title from the
//     feed, cited by deep link into Pulse) and lands in pulse_cache under
//     'presidential_actions' for the feed.
//   * congress.gov bills/laws and Federal Register EO numbers: a change
//     sends the classic SILENT content-available push; the on-device
//     brain decides what to surface.
//
// State lives in the database, reached ONLY through the service-role RPCs
// washington_poll / washington_log_push. Never use PostgREST
// .schema("app"): the app schema is not exposed through PostgREST, reads
// return null and writes fail silently, which turned every poll into a
// silent "first run" for five weeks (2026-08 incident).
//   * congress.gov / Federal Register: single watermarks in
//     app.push_signal (a change means "wake the phones").
//   * White House: a seen-list (app.wh_seen). An action alerts on the poll
//     that first observes it and never again, so a reordered, edited or
//     withdrawn feed entry cannot re-alert (migration 20261115000100).
//
// Every push carries an apns-collapse-id, so a resend replaces the earlier
// notification on the phone instead of stacking beside it; visible alerts
// also carry a thread id so they group on the lock screen. The pure
// decisions (who may call, what to send, the APNs requests) live in
// logic.ts and are tested by logic_test.ts.
//
// Secrets (function env): APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID,
// APNS_TOPIC, APNS_ENV, SB_SECRET_KEY / SUPABASE_SERVICE_ROLE_KEY,
// SUPABASE_URL, CRON_SECRET (REQUIRED: the function refuses every request
// when it is unset; callers present it in the X-Cron-Secret header).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  alertRequest,
  authorize,
  parseWhNew,
  planPush,
  type PushPlan,
  silentRequest,
  type WhAction,
} from "./logic.ts";

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
  const s = btoa(String.fromCharCode(...bytes));
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

// ── push sender ─────────────────────────────────────────────────────────────
async function sendPush(
  jwt: string,
  token: string,
  plan: Exclude<PushPlan, { kind: "none" }>,
): Promise<number> {
  const topic = Deno.env.get("APNS_TOPIC") ?? "io.politiface.politiface";
  const req = plan.kind === "alert"
    ? alertRequest(topic, jwt, plan)
    : silentRequest(topic, jwt);
  const res = await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: req.headers,
    body: req.body,
  });
  return res.status;
}

// ── White House presidential actions (RSS, keyless) ─────────────────────────
function decodeEntities(s: string): string {
  return s
    .replace(/<!\[CDATA\[(.*?)\]\]>/gs, "$1")
    .replace(/&amp;/g, "&")
    .replace(/&#8217;|&rsquo;/g, "'")
    .replace(/&#8220;|&#8221;|&ldquo;|&rdquo;/g, '"')
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .trim();
}

function kindOf(categories: string[]): string {
  const joined = categories.join(" ").toLowerCase();
  if (joined.includes("executive order")) return "executive_order";
  if (joined.includes("proclamation")) return "proclamation";
  if (joined.includes("memorand")) return "memorandum";
  return "presidential_action";
}

async function fetchWhActions(): Promise<WhAction[] | null> {
  try {
    const res = await fetch(
      "https://www.whitehouse.gov/presidential-actions/feed/",
      { headers: { "user-agent": "Politiface/1.0 (civic education app)" } },
    );
    if (!res.ok) {
      console.error(`whitehouse.gov feed ${res.status}`);
      return null;
    }
    const xml = await res.text();
    const items: WhAction[] = [];
    for (const m of xml.matchAll(/<item>([\s\S]*?)<\/item>/g)) {
      const item = m[1];
      const pick = (tag: string) =>
        decodeEntities((item.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`))?.[1] ?? ""));
      const categories = [...item.matchAll(/<category>([\s\S]*?)<\/category>/g)]
        .map((c) => decodeEntities(c[1]));
      const guid = pick("guid") || pick("link");
      const title = pick("title");
      if (!guid || !title) continue;
      const published = pick("pubDate");
      items.push({
        guid,
        title,
        url: pick("link"),
        published_at: published ? new Date(published).toISOString() : "",
        kind: kindOf(categories),
      });
      if (items.length >= 10) break;
    }
    return items;
  } catch (e) {
    console.error("whitehouse.gov feed failed", e);
    return null;
  }
}

// ── congress.gov (via the pulse function) + Federal Register ────────────────
type PulseBill = {
  bill?: string;
  action_date?: string | null;
  action?: string | null;
};

function isEnactedLaw(b: PulseBill): boolean {
  return (b.action ?? "").toLowerCase().includes("became public law");
}

async function latestEoNumber(): Promise<number | null> {
  try {
    const res = await fetch(
      "https://www.federalregister.gov/api/v1/documents.json" +
        "?conditions%5Btype%5D%5B%5D=PRESDOCU" +
        "&conditions%5Bpresidential_document_type%5D%5B%5D=executive_order" +
        "&per_page=1&order=newest&fields%5B%5D=executive_order_number",
    );
    if (!res.ok) {
      console.error(`federalregister.gov ${res.status}`);
      return null;
    }
    const data = await res.json();
    const n = Number(data.results?.[0]?.executive_order_number);
    return Number.isFinite(n) && n > 0 ? n : null;
  } catch (e) {
    console.error("federalregister.gov failed", e);
    return null;
  }
}

// ── poll: observe everything, let the database decide what is new ───────────
type PollResult = {
  changed: boolean;
  first_run: boolean;
  wh_new: WhAction[];
  errors: string[];
};

async function pollForNews(): Promise<PollResult> {
  const errors: string[] = [];

  // Bills via the pulse function (congress.gov key stays in one place).
  let latestBillDate: string | null = null;
  let latestLaw: string | null = null;
  try {
    const pulseRes = await fetch(`${SUPABASE_URL}/functions/v1/pulse`, {
      headers: { "authorization": `Bearer ${SERVICE_KEY}` },
    });
    if (pulseRes.ok) {
      const pulse = await pulseRes.json();
      const bills = (pulse.bills ?? []) as PulseBill[];
      const laws = bills.filter(isEnactedLaw);
      latestLaw = laws
        .map((l) => `${l.action_date ?? ""}:${l.bill ?? ""}`)
        .sort()
        .pop() ?? null;
      latestBillDate = bills[0]?.action_date ?? null;
    } else {
      errors.push(`pulse ${pulseRes.status}`);
    }
  } catch (e) {
    errors.push(`pulse: ${e}`);
  }

  const latestEo = await latestEoNumber();
  const whActions = await fetchWhActions();

  // Keep the feed lane fresh regardless of push outcomes.
  if (whActions && whActions.length) {
    const { error } = await admin.from("pulse_cache").upsert({
      key: "presidential_actions",
      payload: whActions,
      fetched_at: new Date().toISOString(),
    });
    if (error) errors.push(`cache: ${error.message}`);
  }

  // The whole White House window goes to the database, which answers with
  // the entries it has never seen before. Null (feed unreachable or empty)
  // means "no observation": nothing is recorded and nothing fires.
  const { data, error } = await admin.rpc("washington_poll", {
    p_eo: latestEo,
    p_bill: latestBillDate,
    p_law: latestLaw,
    p_wh: whActions && whActions.length ? whActions : null,
  });
  if (error) {
    // The one mistake this function is never allowed to repeat: failing
    // to persist its state QUIETLY. Loud, and visible in the response.
    console.error("washington_poll failed", error.message);
    errors.push(`poll: ${error.message}`);
    return { changed: false, first_run: false, wh_new: [], errors };
  }

  return {
    changed: Boolean(data?.changed),
    first_run: Boolean(data?.first_run),
    wh_new: parseWhNew(data?.wh_new),
    errors,
  };
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
  // Refuses when CRON_SECRET is unset, rather than running for anyone.
  const denied = authorize(
    Deno.env.get("CRON_SECRET"),
    req.headers.get("X-Cron-Secret"),
  );
  if (denied) {
    if (denied.status === 503) console.error(denied.message);
    return new Response(denied.message, { status: denied.status });
  }
  const force = req.method === "POST" &&
    new URL(req.url).searchParams.get("force") === "1";

  const poll = await pollForNews();
  const plan = await planPush(poll.wh_new, poll.changed, force);
  if (plan.kind === "none") {
    return Response.json({
      sent: 0,
      reason: poll.first_run ? "baselined" : "no new activity",
      errors: poll.errors,
    });
  }

  const tokens = await allTokens();
  if (!tokens.length) {
    return Response.json({ sent: 0, reason: "no tokens", errors: poll.errors });
  }

  const jwt = await providerToken();
  let sent = 0;
  const dead: string[] = [];
  for (const row of tokens) {
    try {
      const status = await sendPush(jwt, row.token, plan);
      if (status === 200) sent++;
      else if (status === 410) dead.push(row.token);
      else console.error(`apns ${status}`);
    } catch (e) {
      console.error("apns send failed", e);
    }
  }
  if (dead.length) {
    await admin.from("push_tokens").delete().in("token", dead);
  }
  const { error: logErr } = await admin.rpc("washington_log_push", {
    p_category: plan.kind === "alert" ? "washington_alert" : "washington_silent",
    p_title: plan.kind === "alert" ? plan.logTitle : null,
    p_sent: sent,
  });
  if (logErr) console.error("washington_log_push failed", logErr.message);

  return Response.json({
    sent,
    pruned: dead.length,
    kind: plan.kind,
    errors: poll.errors,
  });
});
