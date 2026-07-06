// The Pulse proxy: near-real-time congress.gov data for the client feed.
//
// The congress.gov API key lives ONLY here (function secret). Responses
// are cached in app.pulse_cache for 15 minutes so the whole install base
// costs a handful of upstream requests per hour, far under the rate
// limit. Public government data; requires only the anon key like any
// function call.
//
// GET -> { fetched_at, bills: [{bill, title, action_date, action, url}] }

import { createClient } from "jsr:@supabase/supabase-js@2";

const TTL_MS = 15 * 60 * 1000;

const SLUGS: Record<string, string> = {
  HR: "house-bill",
  S: "senate-bill",
  HJRES: "house-joint-resolution",
  SJRES: "senate-joint-resolution",
  HCONRES: "house-concurrent-resolution",
  SCONRES: "senate-concurrent-resolution",
  HRES: "house-resolution",
  SRES: "senate-resolution",
};

function webUrl(congress: number, type: string, number: string): string {
  const slug = SLUGS[type?.toUpperCase()] ?? type?.toLowerCase();
  return `https://www.congress.gov/bill/${congress}th-congress/${slug}/${number}`;
}

Deno.serve(async (_req) => {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: cached } = await admin
    .from("pulse_cache")
    .select("payload, fetched_at")
    .eq("key", "bills")
    .maybeSingle();

  if (
    cached &&
    Date.now() - new Date(cached.fetched_at).getTime() < TTL_MS
  ) {
    return Response.json({
      fetched_at: cached.fetched_at,
      bills: cached.payload,
    });
  }

  const key = Deno.env.get("CONGRESS_GOV_API_KEY");
  if (!key) {
    // Not configured: serve stale cache if any, else empty.
    return Response.json({
      fetched_at: cached?.fetched_at ?? null,
      bills: cached?.payload ?? [],
    });
  }

  try {
    const res = await fetch(
      `https://api.congress.gov/v3/bill?api_key=${key}` +
        `&format=json&sort=updateDate+desc&limit=50`,
    );
    if (!res.ok) throw new Error(`congress.gov ${res.status}`);
    const data = await res.json();
    const bills = (data.bills ?? []).map((b: Record<string, unknown>) => {
      const action = (b.latestAction ?? {}) as Record<string, unknown>;
      return {
        bill: `${b.type} ${b.number}`,
        title: ((b.title as string) ?? "").trim(),
        action_date: action.actionDate ?? null,
        action: ((action.text as string) ?? "").trim(),
        url: webUrl(
          (b.congress as number) ?? 0,
          (b.type as string) ?? "",
          String(b.number ?? ""),
        ),
      };
    });

    const fetchedAt = new Date().toISOString();
    await admin.from("pulse_cache").upsert({
      key: "bills",
      payload: bills,
      fetched_at: fetchedAt,
    });
    return Response.json({ fetched_at: fetchedAt, bills });
  } catch (e) {
    console.error("pulse refresh failed", e);
    // Upstream down: stale beats empty.
    return Response.json({
      fetched_at: cached?.fetched_at ?? null,
      bills: cached?.payload ?? [],
    });
  }
});
