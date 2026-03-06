import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildEmail } from "../_shared/email-layout.ts";

const APP_URL = "https://app.reflect-os.com";
const FROM = "Reflect OS <noreply@reflect-os.com>";

Deno.serve(async (req: Request) => {
  try {
    // ── Auth ──────────────────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization" }, 401);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: { user }, error: authError } = await supabaseAdmin.auth
      .getUser(authHeader.replace("Bearer ", ""));
    if (authError || !user?.email) {
      return json({ error: "Unauthorized" }, 401);
    }

    // ── Check notification preferences ───────────────────────────────────
    const { data: prefs } = await supabaseAdmin
      .from("notification_preferences")
      .select("weekly_digest_enabled")
      .eq("user_id", user.id)
      .maybeSingle();

    if (prefs?.weekly_digest_enabled === false) {
      return json({ message: "Weekly digest disabled for this user" });
    }

    // ── Query decisions (user-scoped via JWT so RLS applies) ──────────────
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const today = new Date();
    const in7Days = new Date(today);
    in7Days.setDate(today.getDate() + 7);
    const weekAgo = new Date(today);
    weekAgo.setDate(today.getDate() - 7);

    const todayStr = today.toISOString().split("T")[0];
    const in7DaysStr = in7Days.toISOString().split("T")[0];
    const weekAgoISO = weekAgo.toISOString();

    const [activeRes, dueRes, closedRes] = await Promise.all([
      userClient
        .from("decisions")
        .select("id", { count: "exact", head: true })
        .eq("state", "Active")
        .is("deleted_at", null),
      userClient
        .from("decisions")
        .select("id, title, decision_deadline, stakes")
        .eq("state", "Active")
        .gte("decision_deadline", todayStr)
        .lte("decision_deadline", in7DaysStr)
        .is("deleted_at", null)
        .order("decision_deadline", { ascending: true }),
      userClient
        .from("decisions")
        .select("id", { count: "exact", head: true })
        .eq("state", "Closed")
        .gte("updated_at", weekAgoISO)
        .is("deleted_at", null),
    ]);

    const totalActive = activeRes.count ?? 0;
    const dueThisWeek: Array<{
      id: string;
      title: string;
      decision_deadline: string | null;
      stakes: string | null;
    }> = dueRes.data ?? [];
    const closedThisWeek = closedRes.count ?? 0;

    // ── Build HTML ────────────────────────────────────────────────────────
    const atAGlanceHtml = `
      <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
          <td align="center" style="padding:8px 4px;">
            <div style="font-size:28px;font-weight:700;color:#0D7377;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">${totalActive}</div>
            <div style="font-size:11px;color:#666;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">Active decisions</div>
          </td>
          <td align="center" style="padding:8px 4px;">
            <div style="font-size:28px;font-weight:700;color:#0D7377;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">${dueThisWeek.length}</div>
            <div style="font-size:11px;color:#666;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">Due this week</div>
          </td>
          <td align="center" style="padding:8px 4px;">
            <div style="font-size:28px;font-weight:700;color:#0D7377;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">${closedThisWeek}</div>
            <div style="font-size:11px;color:#666;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">Closed this week</div>
          </td>
        </tr>
      </table>`;

    const dueListHtml = dueThisWeek.length === 0
      ? `<p style="margin:0;color:#666;font-style:italic;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">No decisions due in the next 7 days — you're all caught up.</p>`
      : dueThisWeek.map((d) => {
        const deadline = d.decision_deadline
          ? new Date(d.decision_deadline + "T00:00:00").toLocaleDateString(
            "en-GB",
            { weekday: "short", day: "numeric", month: "short" },
          )
          : "No deadline";
        const stakesLabel = d.stakes ? ` &middot; ${d.stakes} stakes` : "";
        return `<div style="margin-bottom:12px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
          <a href="${APP_URL}/decisions/detail/${d.id}"
             style="font-weight:600;color:#0D7377;text-decoration:none;font-size:14px;">${d.title}</a>
          <div style="font-size:12px;color:#666;margin-top:2px;">Due ${deadline}${stakesLabel}</div>
        </div>`;
      }).join("");

    const html = buildEmail({
      title: "Your Reflect OS Weekly Digest",
      preheader: `${totalActive} active decisions · ${dueThisWeek.length} due this week · ${closedThisWeek} closed`,
      sections: [
        { heading: "At a Glance", html: atAGlanceHtml },
        { heading: "Decisions Due This Week", html: dueListHtml },
      ],
      ctaLabel: "Open Reflect OS",
      ctaUrl: `${APP_URL}/decisions/list`,
    });

    // ── Send via Resend ───────────────────────────────────────────────────
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!resendApiKey) {
      return json({ error: "RESEND_API_KEY not configured" }, 500);
    }

    const sendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM,
        to: [user.email],
        subject: "Your Reflect OS Weekly Digest",
        html,
      }),
    });

    if (!sendRes.ok) {
      const detail = await sendRes.text();
      return json({ error: "Failed to send email", detail }, 500);
    }

    return json({ message: "Weekly digest sent" });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
