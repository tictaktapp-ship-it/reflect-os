import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function durationLabel(createdAt: string, closedAt?: string): string {
  const start = new Date(createdAt).getTime();
  const end = closedAt ? new Date(closedAt).getTime() : Date.now();
  const days = Math.round((end - start) / (1000 * 60 * 60 * 24));
  if (days < 7) return `${days} day${days !== 1 ? "s" : ""}`;
  const weeks = Math.round(days / 7);
  if (weeks < 8) return `${weeks} week${weeks !== 1 ? "s" : ""}`;
  const months = Math.round(days / 30);
  return `${months} month${months !== 1 ? "s" : ""}`;
}

function calibrationLabel(gap: number): string {
  if (gap > 20) return "significantly overconfident";
  if (gap > 5) return "slightly overconfident";
  if (gap < -20) return "significantly underconfident";
  if (gap < -5) return "slightly underconfident";
  return "well-calibrated";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization" }, 401);

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { decision_id } = await req.json();
    if (!decision_id) return json({ error: "decision_id required" }, 400);

    // ── Fetch decision ────────────────────────────────────────────────────
    const { data: decision, error: decErr } = await supabaseAdmin
      .from("decisions")
      .select(
        "id, title, state, stakes, initial_confidence, created_at, workspace_id",
      )
      .eq("id", decision_id)
      .single();

    if (decErr || !decision) {
      return json({ error: `Decision not found: ${decErr?.message}` }, 404);
    }

    // ── Fetch outcome updates ─────────────────────────────────────────────
    const { data: outcomes } = await supabaseAdmin
      .from("outcome_updates")
      .select("outcome_state, final_score, notes_encrypted, created_at")
      .eq("decision_id", decision_id)
      .order("created_at", { ascending: false })
      .limit(10);

    const latestOutcome = outcomes?.[0];
    const outcomeState: string = latestOutcome?.outcome_state ?? "Unknown";
    const finalScore: number | null = latestOutcome?.final_score ?? null;

    // ── Fetch risk assessment ─────────────────────────────────────────────
    const { data: riskRows } = await supabaseAdmin
      .from("risk_assessments")
      .select("overall_risk_level")
      .eq("decision_id", decision_id)
      .order("created_at", { ascending: false })
      .limit(1);

    const riskLevel: string = riskRows?.[0]?.overall_risk_level ?? "unknown";

    // ── Fetch coach notes / lessons ───────────────────────────────────────
    const { data: coachNotes } = await supabaseAdmin
      .from("coach_notes")
      .select("content_encrypted, created_at")
      .eq("decision_id", decision_id)
      .order("created_at", { ascending: false })
      .limit(10);

    // ── Fetch confidence triggers (lessons field) ─────────────────────────
    const { data: triggers } = await supabaseAdmin
      .from("confidence_triggers")
      .select("trigger_type, rationale, created_at")
      .eq("decision_id", decision_id)
      .order("created_at", { ascending: true })
      .limit(20);

    // ── Derived metrics ───────────────────────────────────────────────────
    const initialConfidence: number | null =
      decision.initial_confidence ?? null;
    let calibrationGap: number | null = null;
    if (initialConfidence != null && finalScore != null) {
      calibrationGap = initialConfidence - finalScore;
    }

    const duration = durationLabel(
      decision.created_at,
      decision.state === "Closed" ? undefined : undefined,
    );

    // ── Determine quality trajectory from confidence triggers ─────────────
    let qualityTrajectory = "stable";
    if (triggers && triggers.length >= 2) {
      const ups = triggers.filter((t) => t.trigger_type === "increase").length;
      const downs = triggers.filter((t) => t.trigger_type === "decrease")
        .length;
      if (ups > downs + 1) qualityTrajectory = "improving";
      else if (downs > ups + 1) qualityTrajectory = "declining";
    }

    // ── Determine confidence calibration label ────────────────────────────
    const confidenceCalibration =
      calibrationGap != null ? calibrationLabel(calibrationGap) : "unknown";

    // ── Determine verdict ─────────────────────────────────────────────────
    let verdict = "mixed";
    if (finalScore != null) {
      if (finalScore >= 70) verdict = "good";
      else if (finalScore >= 40) verdict = "mixed";
      else verdict = "poor";
    }

    // ── Build Groq prompt ─────────────────────────────────────────────────
    const groqKey = Deno.env.get("GROQ_API_KEY");
    if (!groqKey) return json({ error: "GROQ_API_KEY not configured" }, 500);

    const coachNotesText =
      coachNotes && coachNotes.length > 0
        ? coachNotes
            .map(
              (n, i) => `${i + 1}. ${n.content_encrypted ?? "(no content)"}`,
            )
            .join("\n")
        : "No coach notes recorded.";

    const triggersText =
      triggers && triggers.length > 0
        ? triggers
            .map(
              (t) =>
                `- ${t.trigger_type}: ${t.rationale ?? "(no rationale)"}`,
            )
            .join("\n")
        : "No confidence triggers recorded.";

    const userContent = `Analyse this closed decision and produce a structured debrief.

Decision: ${decision.title}
Stakes: ${decision.stakes ?? "Not specified"}
Duration: ${duration}
Outcome: ${outcomeState}
Initial confidence: ${initialConfidence != null ? `${initialConfidence}%` : "Not set"}
Final score: ${finalScore != null ? `${finalScore}/100` : "Not set"}
Calibration: ${confidenceCalibration}${calibrationGap != null ? ` (gap: ${calibrationGap > 0 ? "+" : ""}${calibrationGap})` : ""}
Risk level: ${riskLevel}

Coach notes recorded during the decision:
${coachNotesText}

Confidence changes recorded:
${triggersText}

Return ONLY a valid JSON object (no markdown, no explanation) with this exact structure:
{
  "verdict": "<good|mixed|poor>",
  "quality_trajectory": "<improving|stable|declining>",
  "confidence_calibration": "<well-calibrated|slightly overconfident|significantly overconfident|slightly underconfident|significantly underconfident>",
  "summary": "Two to three sentence overall assessment of this decision and key learning.",
  "key_lessons": ["lesson 1", "lesson 2", "lesson 3"],
  "what_worked": ["thing 1", "thing 2", "thing 3"],
  "what_to_improve": ["improvement 1", "improvement 2", "improvement 3"],
  "pattern_flags": []
}

Rules:
- verdict, quality_trajectory, confidence_calibration must match the computed values above exactly
- key_lessons: 3 specific lessons from this decision's journey
- what_worked: 3 things that demonstrated good decision-making practice
- what_to_improve: 3 specific, actionable improvements for next time
- pattern_flags: any behavioural patterns worth flagging (e.g. "confirmation bias", "scope creep") — empty array if none
- Be specific to this decision, not generic`;

    const groqRes = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${groqKey}`,
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: [
            {
              role: "system",
              content:
                "You are an expert decision coach helping executives learn from their past decisions. Be direct, specific, and constructive.",
            },
            { role: "user", content: userContent },
          ],
          temperature: 0.4,
          max_tokens: 1000,
        }),
      },
    );

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      return json(
        { error: `Groq API error ${groqRes.status}: ${errText}` },
        502,
      );
    }

    const groqData = await groqRes.json();
    const rawText: string | undefined =
      groqData?.choices?.[0]?.message?.content;
    if (!rawText) return json({ error: "Empty response from Groq" }, 502);

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(rawText);
    } catch {
      return json({ error: "Could not parse Groq JSON response" }, 502);
    }

    // Override AI verdict/calibration with computed values for consistency.
    const outputJsonb = {
      ...parsed,
      verdict,
      quality_trajectory: qualityTrajectory,
      confidence_calibration: confidenceCalibration,
    };

    // ── Identify requesting user ──────────────────────────────────────────
    const { data: userRow } = await supabaseUser.auth.getUser();
    const requestedByUserId = userRow?.user?.id ?? "";

    // ── Insert into decision_debriefs ─────────────────────────────────────
    const { data: saved, error: saveErr } = await supabaseAdmin
      .from("decision_debriefs")
      .insert({
        decision_id,
        workspace_id: decision.workspace_id,
        requested_by_user_id: requestedByUserId,
        provider: "groq",
        model: "llama-3.3-70b-versatile",
        status: "complete",
        output_jsonb: outputJsonb,
      })
      .select()
      .single();

    if (saveErr) {
      return json({ error: `Failed to save debrief: ${saveErr.message}` }, 500);
    }

    return json(saved);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
