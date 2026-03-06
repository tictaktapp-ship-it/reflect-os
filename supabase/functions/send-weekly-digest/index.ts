import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// send-weekly-digest
// Sends a weekly summary email to the requesting user.
//
// TODO: Configure an email provider (e.g. Resend, SendGrid) and replace the
// stub body below with real logic:
//   1. Read the user's workspace notification preferences from Supabase.
//   2. Query recent decisions and checkpoints for the workspace.
//   3. Render an HTML digest and send via the email provider API.

Deno.serve(async (_req: Request) => {
  return new Response(
    JSON.stringify({ message: "Weekly digest queued successfully" }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
