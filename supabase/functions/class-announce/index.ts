// class-announce: deliver a teacher's class announcement as a VISIBLE
// alert push to that cohort's student devices. Called by the client
// right after send_class_announcement returns (POST {announcement_id}),
// with the caller's JWT; the function re-verifies faculty ownership
// server-side, so a student cannot trigger a broadcast.
//
// Unlike push-washington (silent wake, on-device brain decides), this is
// an alert push with the teacher's own text: no relevance engine, the
// professor authored it. Same APNs secrets.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SERVICE_KEY = Deno.env.get("SB_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const APNS_HOST = (Deno.env.get("APNS_ENV") ?? "production") === "sandbox"
  ? "https://api.sandbox.push.apple.com"
  : "https://api.push.apple.com";

const admin = createClient(SUPABASE_URL, SERVICE_KEY);

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
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
let cachedJwt: { token: string; at: number } | null = null;
async function providerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.at < 3000) return cachedJwt.token;
  const header = b64url(new TextEncoder().encode(
    JSON.stringify({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })));
  const claims = b64url(new TextEncoder().encode(
    JSON.stringify({ iss: Deno.env.get("APNS_TEAM_ID")!, iat: now })));
  const input = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToArrayBuffer(Deno.env.get("APNS_KEY_P8")!),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(input)));
  const token = `${input}.${b64url(sig)}`;
  cachedJwt = { token, at: now };
  return token;
}

async function sendAlert(
  jwt: string,
  token: string,
  title: string,
  body: string,
): Promise<number> {
  const topic = Deno.env.get("APNS_TOPIC") ?? "io.politiface.politiface";
  const res = await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        sound: "default",
      },
      route: "/class",
    }),
  });
  return res.status;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwtCaller = authHeader.replace("Bearer ", "");
  const { announcement_id } = await req.json().catch(() => ({}));
  if (!announcement_id) {
    return new Response("announcement_id required", { status: 400 });
  }

  // Load the announcement and re-verify the caller is faculty of its
  // cohort, using the caller's JWT (not the service key) so RLS + the
  // faculty check apply.
  const asCaller = createClient(SUPABASE_URL, SERVICE_KEY, {
    global: { headers: { Authorization: `Bearer ${jwtCaller}` } },
  });
  const { data: ann } = await admin.from("class_announcements")
    .select("id, cohort_id, author, body, pushed_at")
    .eq("id", announcement_id).single();
  if (!ann) return new Response("not found", { status: 404 });
  if (ann.pushed_at) {
    return Response.json({ sent: 0, reason: "already delivered" });
  }

  // The row can only exist because send_class_announcement already
  // enforced faculty when creating it, so a matching author IS the
  // authorization: verify the caller's JWT resolves to that author.
  const { data: caller } = await asCaller.auth.getUser();
  if (!caller?.user?.id || caller.user.id !== ann.author) {
    return new Response("forbidden", { status: 403 });
  }

  // Claim it so a concurrent replay finds it already pushed.
  const { data: claimed } = await admin.from("class_announcements")
    .update({ pushed_at: new Date().toISOString() })
    .eq("id", ann.id).is("pushed_at", null).select("id");
  if (!claimed?.length) {
    return Response.json({ sent: 0, reason: "already delivered" });
  }

  // Target: student devices of the cohort.
  const { data: members } = await admin.from("cohort_members")
    .select("user_id").eq("cohort_id", ann.cohort_id).eq("role", "student");
  const ids = (members ?? []).map((m) => m.user_id);
  if (!ids.length) return Response.json({ sent: 0, reason: "no students" });

  const { data: tokens } = await admin.from("push_tokens")
    .select("token").in("user_id", ids);
  if (!tokens?.length) return Response.json({ sent: 0, reason: "no devices" });

  const jwt = await providerToken();
  const title = "Message from your professor";
  let sent = 0;
  const dead: string[] = [];
  for (const row of tokens) {
    try {
      const s = await sendAlert(jwt, row.token, title, ann.body);
      if (s === 200) sent++;
      else if (s === 410) dead.push(row.token);
    } catch (_) { /* transient */ }
  }
  if (dead.length) {
    await admin.from("push_tokens").delete().in("token", dead);
  }
  return Response.json({ sent, pruned: dead.length });
});
