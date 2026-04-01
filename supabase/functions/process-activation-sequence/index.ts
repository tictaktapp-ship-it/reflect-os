/**
 * process-activation-sequence
 *
 * Processes pending activation-sequence notifications from notification_queue
 * and sends branded emails via Resend.
 *
 * Intended to run on a daily cron (e.g. pg_cron or Supabase scheduled functions).
 * Can also be invoked manually via HTTP POST with a service-role bearer token.
 *
 * Query scope: notification_type LIKE 'activation_%', status = 'Pending',
 *              scheduled_for <= now()
 */

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildEmail } from "../_shared/email-layout.ts";

const APP_URL = "https://app.reflect-os.com";
const FROM = "Reflect OS <noreply@reflect-os.com>";
const BATCH_SIZE = 50; // process up to 50 notifications per invocation

interface PendingNotification {
  id: string;
  user_id: string;
  notification_type: string;
  title: string;
  body: string;
  scheduled_for: string;
  metadata_jsonb: Record<string, unknown> | null;
}

Deno.serve(async (req: Request) => {
  try {
    // ── Auth: service-role only ───────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization" }, 401);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Validate the token is a service-role key by checking it matches env
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const providedKey = authHeader.replace("Bearer ", "");
    if (providedKey !== serviceRoleKey) {
      return json({ error: "Unauthorized" }, 401);
    }

    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!resendApiKey) {
      return json({ error: "RESEND_API_KEY not configured" }, 500);
    }

    // ── Fetch due notifications ───────────────────────────────────────────
    const now = new Date().toISOString();

    const { data: pending, error: fetchErr } = await supabaseAdmin
      .from("notification_queue")
      .select("id, user_id, notification_type, title, body, scheduled_for, metadata_jsonb")
      .like("notification_type", "activation_%")
      .eq("status", "Pending")
      .lte("scheduled_for", now)
      .limit(BATCH_SIZE);

    if (fetchErr) {
      return json({ error: fetchErr.message }, 500);
    }

    if (!pending || pending.length === 0) {
      return json({ message: "No pending activation notifications." });
    }

    // ── Process each notification ─────────────────────────────────────────
    let sent = 0;
    let failed = 0;
    const errors: string[] = [];

    for (const notification of pending as PendingNotification[]) {
      try {
        // Mark as Processing first to prevent double-delivery on retries.
        await supabaseAdmin
          .from("notification_queue")
          .update({ status: "Processing" })
          .eq("id", notification.id);

        // Fetch user email.
        const { data: { user }, error: userErr } = await supabaseAdmin.auth.admin
          .getUserById(notification.user_id);

        if (userErr || !user?.email) {
          await markFailed(supabaseAdmin, notification.id);
          failed++;
          errors.push(`${notification.id}: no email for user ${notification.user_id}`);
          continue;
        }

        // Check notification preferences (default opted-in).
        const { data: prefs } = await supabaseAdmin
          .from("notification_preferences")
          .select("activation_emails_enabled")
          .eq("user_id", notification.user_id)
          .maybeSingle();

        if (prefs?.activation_emails_enabled === false) {
          // User has opted out — cancel this notification silently.
          await supabaseAdmin
            .from("notification_queue")
            .update({ status: "Cancelled" })
            .eq("id", notification.id);
          continue;
        }

        // Build and send email.
        const html = buildActivationEmail(notification);

        const sendRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${resendApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: FROM,
            to: [user.email],
            subject: notification.title,
            html,
          }),
        });

        if (!sendRes.ok) {
          const detail = await sendRes.text();
          await markFailed(supabaseAdmin, notification.id);
          failed++;
          errors.push(`${notification.id}: Resend error — ${detail}`);
          continue;
        }

        await supabaseAdmin
          .from("notification_queue")
          .update({ status: "Sent" })
          .eq("id", notification.id);

        sent++;
      } catch (err) {
        await markFailed(supabaseAdmin, notification.id).catch(() => {});
        failed++;
        errors.push(`${notification.id}: ${String(err)}`);
      }
    }

    return json({
      message: `Processed ${pending.length} notification(s): ${sent} sent, ${failed} failed.`,
      ...(errors.length > 0 && { errors }),
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────

async function markFailed(
  supabaseAdmin: ReturnType<typeof createClient>,
  id: string,
) {
  await supabaseAdmin
    .from("notification_queue")
    .update({ status: "Failed" })
    .eq("id", id);
}

function ctaForType(type: string): { label: string; url: string } {
  switch (type) {
    case "activation_habit":
    case "activation_review":
      return { label: "Log a Decision", url: `${APP_URL}/decisions/list` };
    case "activation_insight":
    case "activation_pattern":
    case "activation_lockIn":
    case "activation_milestone":
    default:
      return { label: "Open Reflect OS", url: APP_URL };
  }
}

function buildActivationEmail(n: PendingNotification): string {
  const cta = ctaForType(n.notification_type);

  const bodyHtml = `
    <p style="margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
              font-size:15px;line-height:1.6;color:#1a1a2e;">
      ${n.body}
    </p>`;

  return buildEmail({
    title: `${n.title} — Reflect OS`,
    preheader: n.body,
    sections: [
      {
        heading: n.title,
        html: bodyHtml,
      },
    ],
    ctaLabel: cta.label,
    ctaUrl: cta.url,
  });
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
