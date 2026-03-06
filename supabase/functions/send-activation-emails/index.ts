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
    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    // ── Parse body ────────────────────────────────────────────────────────
    const body = await req.json().catch(() => ({}));
    const decisionId: string | undefined = body?.decision_id;
    if (!decisionId) {
      return json({ error: "decision_id is required" }, 400);
    }

    // ── Fetch decision ────────────────────────────────────────────────────
    const { data: decision, error: decisionErr } = await supabaseAdmin
      .from("decisions")
      .select("id, title, stakes, decision_deadline, owner_user_id, workspace_id")
      .eq("id", decisionId)
      .is("deleted_at", null)
      .single();

    if (decisionErr || !decision) {
      return json({ error: "Decision not found" }, 404);
    }

    // ── Fetch stakeholder user IDs ────────────────────────────────────────
    const { data: stakeholders } = await supabaseAdmin
      .from("decision_stakeholders")
      .select("user_id")
      .eq("decision_id", decisionId)
      .is("deleted_at", null);

    const stakeholderUserIds: string[] = (stakeholders ?? []).map((s: {
      user_id: string;
    }) => s.user_id);

    // Collect all recipient user IDs (owner + stakeholders, deduplicated)
    const recipientIds = Array.from(
      new Set([decision.owner_user_id, ...stakeholderUserIds]),
    );

    // ── Fetch notification preferences for all recipients ─────────────────
    const { data: allPrefs } = await supabaseAdmin
      .from("notification_preferences")
      .select("user_id, activation_emails_enabled")
      .in("user_id", recipientIds);

    const prefsMap = new Map<string, boolean>(
      (allPrefs ?? []).map((p: {
        user_id: string;
        activation_emails_enabled: boolean;
      }) => [p.user_id, p.activation_emails_enabled]),
    );

    // Filter to only opted-in recipients (default true if no row exists)
    const optedInIds = recipientIds.filter((id) =>
      prefsMap.get(id) !== false
    );

    if (optedInIds.length === 0) {
      return json({ message: "No opted-in recipients" });
    }

    // ── Fetch emails for opted-in recipients ──────────────────────────────
    const emailPromises = optedInIds.map((id) =>
      supabaseAdmin.auth.admin.getUserById(id).then((res) => res.data.user?.email)
    );
    const emails = (await Promise.all(emailPromises)).filter(Boolean) as string[];

    if (emails.length === 0) {
      return json({ message: "No email addresses found" });
    }

    // ── Build email ───────────────────────────────────────────────────────
    const deadlineLabel = decision.decision_deadline
      ? new Date(decision.decision_deadline + "T00:00:00").toLocaleDateString(
        "en-GB",
        { weekday: "long", day: "numeric", month: "long", year: "numeric" },
      )
      : null;

    const stakesLabel = decision.stakes
      ? `<strong>${decision.stakes} stakes</strong>`
      : null;

    const detailRows = [
      deadlineLabel
        ? `<tr><td style="padding:4px 0;color:#666;font-size:13px;width:90px;">Deadline</td><td style="padding:4px 0;font-size:13px;">${deadlineLabel}</td></tr>`
        : "",
      stakesLabel
        ? `<tr><td style="padding:4px 0;color:#666;font-size:13px;">Stakes</td><td style="padding:4px 0;font-size:13px;">${stakesLabel}</td></tr>`
        : "",
    ].filter(Boolean).join("");

    const decisionHtml = `
      <p style="margin:0 0 12px 0;font-size:16px;font-weight:600;color:#1a1a2e;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">${decision.title}</p>
      ${
      detailRows
        ? `<table cellpadding="0" cellspacing="0" border="0" style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">${detailRows}</table>`
        : ""
    }`;

    const nextStepsHtml = `
      <ul style="margin:0;padding-left:20px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:13px;color:#1a1a2e;line-height:1.8;">
        <li>Review the decision details and add any evidence or context</li>
        <li>Track checkpoints as the decision plays out</li>
        <li>Log the outcome when it's resolved</li>
      </ul>`;

    const html = buildEmail({
      title: "Decision Activated — Reflect OS",
      preheader: `"${decision.title}" has been moved to Active.`,
      sections: [
        {
          heading: "Decision Activated",
          html: decisionHtml,
        },
        {
          heading: "What Happens Next",
          html: nextStepsHtml,
        },
      ],
      ctaLabel: "View Decision",
      ctaUrl: `${APP_URL}/decisions/detail/${decision.id}`,
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
        to: emails,
        subject: `Decision Activated: ${decision.title}`,
        html,
      }),
    });

    if (!sendRes.ok) {
      const detail = await sendRes.text();
      return json({ error: "Failed to send email", detail }, 500);
    }

    return json({ message: `Activation email sent to ${emails.length} recipient(s)` });
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
