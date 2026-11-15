// deno test supabase/functions/push-washington/logic_test.ts
//
// No network and no credentials: only the pure decisions in logic.ts.

import {
  actionRoute,
  alertRequest,
  authorize,
  collapseIdFor,
  parseWhNew,
  planPush,
  SILENT_COLLAPSE_ID,
  silentRequest,
  THREAD_ID,
  timingSafeEqual,
  type WhAction,
} from "./logic.ts";

function eq<T>(actual: T, expected: T, what: string) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${what}: expected ${e}, got ${a}`);
}

const action = (n: number, kind = "executive_order"): WhAction => ({
  guid: `https://www.whitehouse.gov/?p=${n}`,
  title: `Action ${n}`,
  url: `https://www.whitehouse.gov/presidential-actions/${n}/`,
  published_at: "2026-11-15T14:00:00.000Z",
  kind,
});

Deno.test("the function refuses to run when CRON_SECRET is unset", () => {
  // The old gate was `if (cronSecret && header !== cronSecret)`: with no
  // secret configured, anyone could trigger a push to every phone.
  eq(authorize(undefined, null)?.status, 503, "unset, no header");
  eq(authorize(undefined, "anything")?.status, 503, "unset, any header");
  eq(authorize("", "")?.status, 503, "empty secret is not a secret");
});

Deno.test("a wrong or missing secret is forbidden, the right one passes", () => {
  eq(authorize("s3cret", null)?.status, 403, "missing header");
  eq(authorize("s3cret", "")?.status, 403, "empty header");
  eq(authorize("s3cret", "s3cre")?.status, 403, "prefix");
  eq(authorize("s3cret", "s3cret!")?.status, 403, "longer");
  eq(authorize("s3cret", "s3cret"), null, "exact match");
});

Deno.test("timingSafeEqual", () => {
  eq(timingSafeEqual("abc", "abc"), true, "same");
  eq(timingSafeEqual("abc", "abd"), false, "differs");
  eq(timingSafeEqual("abc", "abcd"), false, "length");
  eq(timingSafeEqual("", ""), true, "empty");
});

Deno.test("collapse id is stable, order-free, and within 64 bytes", async () => {
  const a = await collapseIdFor(["g1", "g2"]);
  eq(a, await collapseIdFor(["g2", "g1"]), "order must not matter");
  eq(a === (await collapseIdFor(["g1"])), false, "different set");
  const long = await collapseIdFor(["x".repeat(5000)]);
  eq(new TextEncoder().encode(long).length <= 64, true, "apns limit");
  eq(/^wh-[0-9a-f]{40}$/.test(long), true, "shape");
});

Deno.test("one new action: a named alert that opens its own page", async () => {
  const plan = await planPush([action(1, "proclamation")], true, false);
  if (plan.kind !== "alert") throw new Error("expected an alert");
  eq(plan.title, "New proclamation", "title");
  eq(plan.body, "Action 1", "body");
  eq(plan.route, actionRoute(action(1, "proclamation")), "route");
  eq(plan.collapseId, await collapseIdFor([action(1).guid]), "collapse id");
});

Deno.test("several new actions: one alert, not one per action", async () => {
  const plan = await planPush([action(3), action(2), action(1)], true, false);
  if (plan.kind !== "alert") throw new Error("expected an alert");
  eq(plan.title, "3 new presidential actions", "title");
  eq(plan.body, "Action 3, and 2 more.", "body");
  eq(plan.route, "/pulse", "route");
});

Deno.test("no new action: silent when something changed, else nothing", async () => {
  eq((await planPush([], true, false)).kind, "silent", "changed");
  eq((await planPush([], false, true)).kind, "silent", "forced");
  eq((await planPush([], false, false)).kind, "none", "quiet");
});

Deno.test("alert request carries the collapse id and the thread id", async () => {
  const plan = await planPush([action(1)], true, false);
  if (plan.kind !== "alert") throw new Error("expected an alert");
  const req = alertRequest("io.example.app", "jwt", plan);
  eq(req.headers["apns-collapse-id"], plan.collapseId, "collapse header");
  eq(req.headers["apns-push-type"], "alert", "push type");
  const body = JSON.parse(req.body);
  eq(body.aps["thread-id"], THREAD_ID, "thread id");
  eq(body.aps.alert, { title: "New executive order", body: "Action 1" }, "alert");
  eq(body.payload, plan.route, "payload route");
  eq(body.route, plan.route, "route");
});

Deno.test("silent request carries one shared collapse id", () => {
  const req = silentRequest("io.example.app", "jwt");
  eq(req.headers["apns-collapse-id"], SILENT_COLLAPSE_ID, "collapse header");
  eq(req.headers["apns-push-type"], "background", "push type");
  eq(JSON.parse(req.body).aps, { "content-available": 1 }, "aps");
});

Deno.test("parseWhNew drops anything malformed", () => {
  eq(parseWhNew(null), [], "null");
  eq(parseWhNew({}), [], "object");
  eq(
    parseWhNew([
      { guid: "g1", title: "T1", url: "u", kind: "memorandum", published_at: "p" },
      { guid: "", title: "no id" },
      { guid: "g2" },
      "nonsense",
      { guid: "g3", title: "T3" },
    ]),
    [
      { guid: "g1", title: "T1", url: "u", published_at: "p", kind: "memorandum" },
      { guid: "g3", title: "T3", url: "", published_at: "", kind: "presidential_action" },
    ],
    "kept",
  );
});
