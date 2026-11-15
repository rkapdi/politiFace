// Pure decision logic for push-washington: no network, no env, no database.
// Kept apart from index.ts so it can be tested with `deno test` (see
// logic_test.ts) without credentials.

export type WhAction = {
  guid: string;
  title: string;
  url: string;
  published_at: string;
  kind: string;
};

/// What to send for one poll.
///   alert  a visible notification about White House action(s)
///   silent the content-available wake; the phone decides what to surface
///   none   nothing changed
export type PushPlan =
  | {
    kind: "alert";
    title: string;
    body: string;
    route: string;
    collapseId: string;
    logTitle: string;
  }
  | { kind: "silent"; collapseId: string }
  | { kind: "none" };

/// Groups every Washington notification into one stack on the lock screen.
export const THREAD_ID = "washington";

/// One collapse id for every silent wake: if a phone was offline through
/// several polls, APNs keeps only the latest instead of delivering a queue
/// of identical wakes.
export const SILENT_COLLAPSE_ID = "washington-refresh";

export function kindLabel(kind: string): string {
  switch (kind) {
    case "executive_order":
      return "New executive order";
    case "proclamation":
      return "New proclamation";
    case "memorandum":
      return "New presidential memorandum";
    default:
      return "New presidential action";
  }
}

/// Gate for the whole function. The secret is REQUIRED: with none
/// configured the function refuses every request, instead of running for
/// anyone who finds the URL.
///   503  CRON_SECRET is not set on the function (misconfiguration)
///   403  the caller did not present it
///   null authorized
export function authorize(
  cronSecret: string | undefined,
  presented: string | null,
): { status: number; message: string } | null {
  if (!cronSecret) {
    return { status: 503, message: "CRON_SECRET is not configured" };
  }
  if (presented === null || !timingSafeEqual(presented, cronSecret)) {
    return { status: 403, message: "forbidden" };
  }
  return null;
}

/// Compares without stopping at the first differing character, so response
/// time does not leak how much of a guess was right.
export function timingSafeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

/// A stable apns-collapse-id for a set of feed entries: the same entries
/// always produce the same id (so a resend replaces the earlier
/// notification on the phone instead of stacking beside it), and it stays
/// within APNs' 64-byte limit however long the guids are.
export async function collapseIdFor(guids: string[]): Promise<string> {
  const bytes = new TextEncoder().encode([...guids].sort().join("\n"));
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  const hex = [...digest].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `wh-${hex.slice(0, 40)}`;
}

/// The deep link for one action: the detail screen, with everything it
/// needs to render without a network round trip.
export function actionRoute(a: WhAction): string {
  return "/pulse/action?" + new URLSearchParams({
    t: a.title,
    u: a.url,
    k: a.kind,
    d: a.published_at,
  }).toString();
}

/// Reads the `wh_new` array washington_poll returned. Anything that is not
/// a well-formed entry is dropped rather than trusted.
export function parseWhNew(raw: unknown): WhAction[] {
  if (!Array.isArray(raw)) return [];
  const out: WhAction[] = [];
  for (const r of raw) {
    if (!r || typeof r !== "object") continue;
    const o = r as Record<string, unknown>;
    const guid = typeof o.guid === "string" ? o.guid : "";
    const title = typeof o.title === "string" ? o.title : "";
    if (!guid || !title) continue;
    out.push({
      guid,
      title,
      url: typeof o.url === "string" ? o.url : "",
      published_at: typeof o.published_at === "string" ? o.published_at : "",
      kind: typeof o.kind === "string" ? o.kind : "presidential_action",
    });
  }
  return out;
}

/// Decides what one poll sends.
///   * New White House action(s): ONE visible alert. A single action is
///     named and opens its own page; several at once are counted, named by
///     the newest, and open The Pulse.
///   * Otherwise, if a congress.gov / Federal Register watermark moved (or
///     the caller forced a send): the silent wake.
///   * Otherwise nothing.
export async function planPush(
  whNew: WhAction[],
  changed: boolean,
  force: boolean,
): Promise<PushPlan> {
  if (whNew.length === 1) {
    const a = whNew[0];
    return {
      kind: "alert",
      title: kindLabel(a.kind),
      body: a.title,
      route: actionRoute(a),
      collapseId: await collapseIdFor([a.guid]),
      logTitle: a.title,
    };
  }
  if (whNew.length > 1) {
    const newest = whNew[0];
    const others = whNew.length - 1;
    return {
      kind: "alert",
      title: `${whNew.length} new presidential actions`,
      body: `${newest.title}, and ${others} more.`,
      route: "/pulse",
      collapseId: await collapseIdFor(whNew.map((a) => a.guid)),
      logTitle: `${whNew.length} actions: ${newest.title}`,
    };
  }
  if (changed || force) {
    return { kind: "silent", collapseId: SILENT_COLLAPSE_ID };
  }
  return { kind: "none" };
}

/// The APNs request for a visible alert: headers and JSON body.
export function alertRequest(
  topic: string,
  jwt: string,
  plan: Extract<PushPlan, { kind: "alert" }>,
): { headers: Record<string, string>; body: string } {
  return {
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": plan.collapseId,
    },
    body: JSON.stringify({
      // "payload" is the deep-link route in the dialect the app's
      // notification-tap handler already speaks (it is what
      // flutter_local_notifications surfaces as the response payload);
      // "route" stays for the cold-start stash and older builds.
      aps: {
        alert: { title: plan.title, body: plan.body },
        sound: "default",
        "thread-id": THREAD_ID,
      },
      category: "washington",
      route: plan.route,
      payload: plan.route,
    }),
  };
}

/// The APNs request for the silent wake. No thread id: a background push
/// shows nothing, so there is nothing to group.
export function silentRequest(
  topic: string,
  jwt: string,
): { headers: Record<string, string>; body: string } {
  return {
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "background",
      "apns-priority": "5",
      "apns-collapse-id": SILENT_COLLAPSE_ID,
    },
    body: JSON.stringify({
      aps: { "content-available": 1 },
      category: "washington",
      route: "/pulse",
    }),
  };
}
