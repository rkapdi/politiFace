// The Pulse proxy: near-real-time congress.gov data for the client feed.
//
// The congress.gov API key lives ONLY here (function secret). Responses
// are cached in app.pulse_cache for 15 minutes so the whole install base
// costs a handful of upstream requests per hour, far under the rate
// limit. Public government data; requires only the anon key like any
// function call.
//
// GET -> { fetched_at, bills: [{bill, title, action_date, action, url,
//          congress}] }
// GET ?bill=<congress>/<type>/<number> ->
//   { fetched_at, summary: {text, version, date, truncated} | null }
//   Per-bill CRS summary (public domain, Congressional Research
//   Service), cached 24h under key 'summary:<congress>/<type>/<number>'.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const TTL_MS = 15 * 60 * 1000;
const SUMMARY_TTL_MS = 24 * 60 * 60 * 1000;
const SUMMARY_LIMIT = 2500;
const BILL_PARAM_RE = /^\d{2,3}\/[a-z]{1,7}\/\d{1,6}$/;

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

// CRS summary HTML to plain text with paragraph breaks preserved.
function stripHtml(html: string): string {
  const text = html
    .replace(/<br\s*\/?\s*>/gi, "\n")
    .replace(/<\/(p|li|ul|ol)>/gi, "\n\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"');
  return text
    .replace(/[ \t]+/g, " ")
    .replace(/ ?\n ?/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// Cap at a paragraph break (fallback: sentence) before `limit`. Mirrors
// cap_summary in scripts/fetch_recent_bills.py.
function capSummary(
  text: string,
  limit = SUMMARY_LIMIT,
): [string, boolean] {
  if (text.length <= limit) return [text, false];
  let cut = text.lastIndexOf("\n\n", limit);
  if (cut <= Math.floor(limit / 2)) {
    const sentence = text.slice(0, limit).lastIndexOf(". ");
    cut = sentence === -1 ? limit : sentence + 1;
  }
  return [text.slice(0, cut).trimEnd(), true];
}

type SummaryPayload = {
  text: string;
  version: string;
  date: string;
  truncated: boolean;
};

// pulse_cache.payload is NOT NULL, so a bill known to have no summary is
// cached as {} and normalized back to null here.
function toSummary(payload: unknown): SummaryPayload | null {
  if (
    payload && typeof payload === "object" &&
    typeof (payload as SummaryPayload).text === "string" &&
    (payload as SummaryPayload).text.length > 0
  ) {
    return payload as SummaryPayload;
  }
  return null;
}

async function serveSummary(
  admin: SupabaseClient,
  billParam: string,
): Promise<Response> {
  if (!BILL_PARAM_RE.test(billParam)) {
    return Response.json({ error: "bad bill" }, { status: 400 });
  }
  const cacheKey = `summary:${billParam}`;

  const { data: cached } = await admin
    .from("pulse_cache")
    .select("payload, fetched_at")
    .eq("key", cacheKey)
    .maybeSingle();

  if (
    cached &&
    Date.now() - new Date(cached.fetched_at).getTime() < SUMMARY_TTL_MS
  ) {
    return Response.json({
      fetched_at: cached.fetched_at,
      summary: toSummary(cached.payload),
    });
  }

  const key = Deno.env.get("CONGRESS_GOV_API_KEY");
  if (!key) {
    // Not configured: serve stale cache if any, else null.
    return Response.json({
      fetched_at: cached?.fetched_at ?? null,
      summary: toSummary(cached?.payload),
    });
  }

  try {
    const res = await fetch(
      `https://api.congress.gov/v3/bill/${billParam}/summaries` +
        `?api_key=${key}&format=json`,
    );
    if (!res.ok) throw new Error(`congress.gov ${res.status}`);
    const data = await res.json();
    const docs = (data.summaries ?? []) as Record<string, unknown>[];

    let payload: SummaryPayload | Record<string, never> = {};
    if (docs.length > 0) {
      const newest = docs.reduce((a, b) =>
        String(a.updateDate ?? a.actionDate ?? "") >=
            String(b.updateDate ?? b.actionDate ?? "")
          ? a
          : b
      );
      const [text, truncated] = capSummary(
        stripHtml(String(newest.text ?? "")),
      );
      if (text) {
        payload = {
          text,
          version: String(newest.actionDesc ?? ""),
          date: String(newest.actionDate ?? ""),
          truncated,
        };
      }
    }

    const fetchedAt = new Date().toISOString();
    await admin.from("pulse_cache").upsert({
      key: cacheKey,
      payload,
      fetched_at: fetchedAt,
    });
    // Housekeeping: drop summary rows nobody has refreshed in two weeks
    // so per-bill caching stays bounded.
    await admin
      .from("pulse_cache")
      .delete()
      .like("key", "summary:%")
      .lt(
        "fetched_at",
        new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
      );
    return Response.json({
      fetched_at: fetchedAt,
      summary: toSummary(payload),
    });
  } catch (e) {
    console.error("pulse summary refresh failed", e);
    // Upstream down: stale beats empty.
    return Response.json({
      fetched_at: cached?.fetched_at ?? null,
      summary: toSummary(cached?.payload),
    });
  }
}

// Privileged (bypass-RLS) key. Prefer the new secret key (SB_SECRET_KEY);
// fall back to the injected legacy service_role so this deploys safely in
// any order relative to disabling legacy keys.
const SERVICE_KEY = Deno.env.get("SB_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    SERVICE_KEY,
  );

  const billParam = new URL(req.url).searchParams.get("bill");
  if (billParam !== null) return serveSummary(admin, billParam);

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
        congress: (b.congress as number) ?? null,
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
