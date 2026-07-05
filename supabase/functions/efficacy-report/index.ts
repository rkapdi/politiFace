// The efficacy one-pager: a printable HTML report for one cohort, built
// from cohort_rollups (aggregate, pseudonymous). This is the exportable
// artifact Purcell carries into the president's office.
//
// Auth: the caller's own JWT is forwarded to PostgREST, so RLS decides.
// Only faculty of the cohort can read its rollups; everyone else gets an
// empty result and a 404. No service role, no bypass.
//
// GET ?cohort_id=<uuid>  (Authorization: Bearer <user jwt>)

import { createClient } from "jsr:@supabase/supabase-js@2";

function esc(s: unknown): string {
  return String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ]!,
  );
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const cohortId = url.searchParams.get("cohort_id");
  if (!cohortId) return new Response("cohort_id required", { status: 400 });

  const authHeader = req.headers.get("authorization");
  if (!authHeader) return new Response("unauthorized", { status: 401 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const [{ data: cohort }, { data: rollup }, { data: outcome }] = await Promise
    .all([
      supabase.from("cohorts").select("name, term").eq("id", cohortId)
        .maybeSingle(),
      supabase.from("cohort_rollups").select("*").eq("cohort_id", cohortId)
        .order("computed_at", { ascending: false }).limit(1).maybeSingle(),
      supabase.from("cohort_outcomes").select("*").eq("cohort_id", cohortId)
        .maybeSingle(),
    ]);

  if (!cohort || !rollup) {
    // Not faculty of this cohort (RLS returned nothing) or no data yet.
    return new Response("not found", { status: 404 });
  }

  const baseline = rollup.baseline_avg ?? {};
  const final_ = rollup.final_avg ?? {};
  const lift = rollup.lift ?? {};

  const stat = (label: string, value: unknown, note = "") => `
    <div class="stat">
      <div class="value">${esc(value ?? "–")}</div>
      <div class="label">${esc(label)}</div>
      ${note ? `<div class="note">${esc(note)}</div>` : ""}
    </div>`;

  const html = `<!doctype html>
<html><head><meta charset="utf-8">
<title>Politiface: cohort efficacy summary</title>
<style>
  body { font: 15px/1.5 -apple-system, "Segoe UI", sans-serif; color: #16181d;
         max-width: 720px; margin: 40px auto; padding: 0 24px; }
  h1 { font-size: 22px; margin-bottom: 2px; }
  .sub { color: #5c6270; margin-bottom: 28px; }
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px;
          margin: 20px 0; }
  .stat { border: 1px solid #d9dce3; border-radius: 6px; padding: 14px; }
  .value { font-size: 26px; font-weight: 800; }
  .label { color: #5c6270; font-size: 13px; margin-top: 2px; }
  .note { color: #8a90a0; font-size: 12px; margin-top: 4px; }
  .footer { margin-top: 36px; color: #8a90a0; font-size: 12px;
            border-top: 1px solid #d9dce3; padding-top: 12px; }
  @media print { body { margin: 0; } }
</style></head><body>
  <h1>Civic literacy practice: cohort summary</h1>
  <div class="sub">${esc(cohort.name)}${
    cohort.term ? " · " + esc(cohort.term) : ""
  } · computed ${esc(String(rollup.computed_at).slice(0, 10))}</div>

  <h3>Adoption and engagement</h3>
  <div class="grid">
    ${stat("active students", rollup.active_users)}
    ${stat("practice sessions", rollup.sessions)}
    ${stat("questions answered", rollup.questions_answered)}
  </div>

  <h3>Mock exam movement (80-question mock, 48 to pass)</h3>
  <div class="grid">
    ${
    stat(
      "baseline average",
      baseline.score,
      baseline.n ? `n = ${baseline.n}` : "",
    )
  }
    ${stat("latest average", final_.score, final_.n ? `n = ${final_.n}` : "")}
    ${stat("average lift", lift.score_delta)}
  </div>
  ${
    final_.passing_share != null
      ? `<p>Share of students at or above the passing bar on their latest mock:
         <strong>${esc(Math.round(final_.passing_share * 100))}%</strong>.</p>`
      : ""
  }
  ${
    outcome?.first_attempt_pass_rate != null
      ? `<h3>Official outcome (institution-supplied, aggregate)</h3>
         <p>First-attempt FCLE pass rate:
         <strong>${
        esc(Math.round(outcome.first_attempt_pass_rate * 100))
      }%</strong></p>`
      : ""
  }

  <div class="footer">
    All figures are cohort aggregates from pseudonymous practice data.
    Politiface stores no student education records, no political affiliation,
    and no voting history. Mock results are practice signals, not predictions
    of official FCLE performance.
  </div>
</body></html>`;

  return new Response(html, {
    headers: { "content-type": "text/html; charset=utf-8" },
  });
});
