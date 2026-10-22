// RevenueCat webhook -> entitlements table.
//
// RevenueCat is the source of truth for purchases; this function mirrors its
// events into public.entitlements, which is all the app ever checks.
// Configure in RevenueCat: webhook URL = this function, Authorization header
// = the RC_WEBHOOK_SECRET value. Deploy with verify_jwt disabled (RevenueCat
// cannot mint Supabase JWTs); the shared secret is the auth.
//
// The app must set the RevenueCat appUserID to the Supabase auth user id so
// event.app_user_id maps straight onto entitlements.user_id.

import { createClient } from "jsr:@supabase/supabase-js@2";

const CAPABILITIES = new Set(["full", "fcle", "plus"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const secret = Deno.env.get("RC_WEBHOOK_SECRET");
  if (!secret || req.headers.get("authorization") !== `Bearer ${secret}`) {
    return new Response("unauthorized", { status: 401 });
  }

  // Prefer the new secret key; fall back to the injected legacy
  // service_role so deploy order relative to disabling legacy keys is safe.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SB_SECRET_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let event;
  try {
    event = (await req.json()).event;
  } catch {
    return new Response("bad json", { status: 400 });
  }
  if (!event?.app_user_id) {
    return new Response("no app_user_id", { status: 400 });
  }

  // RevenueCat sends entitlement identifiers; ours are named after the
  // capability flags. Ignore anything unknown rather than failing: a typo'd
  // entitlement in the RC dashboard must not break every webhook delivery.
  const entitlements: string[] = (event.entitlement_ids ?? [])
    .filter((id: string) => CAPABILITIES.has(id));
  if (entitlements.length === 0) {
    return new Response("ok (no mapped entitlements)", { status: 200 });
  }

  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  // EXPIRATION revokes by setting expires_at in the past is unnecessary:
  // RevenueCat already sends the real expiration time on the grant events,
  // and the app treats a past expires_at as no entitlement.
  const rows = entitlements.map((capability) => ({
    user_id: event.app_user_id,
    capability,
    source: "purchase",
    expires_at: expiresAt,
  }));

  const { error } = await admin
    .from("entitlements")
    .upsert(rows, { onConflict: "user_id,capability" });
  if (error) {
    console.error("entitlement upsert failed", error);
    return new Response("upsert failed", { status: 500 });
  }

  return new Response("ok", { status: 200 });
});
