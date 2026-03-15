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

function severityForScore(likelihood: number, impact: number): string {
  const score = likelihood * impact;
  if (score <= 4) return "low";
  if (score <= 9) return "medium";
  if (score <= 16) return "high";
  return "critical";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization" }, 401);

    // Use service role to read the decision, anon client for RLS write.
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
      .select("title, description_encrypted, stakes")
      .eq("id", decision_id)
      .single();

    if (decErr || !decision) {
      return json({ error: `Decision not found: ${decErr?.message}` }, 404);
    }

    // ── Call Gemini ───────────────────────────────────────────────────────
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) return json({ error: "GEMINI_API_KEY not configured" }, 500);

    const prompt = `You are a decision risk assessment expert using the ISO 31000 framework.

Analyse the following decision and identify 3–6 specific, actionable risks.

Decision title: ${decision.title}
Stakes: ${decision.stakes ?? "Not specified"}
Description: ${decision.description_encrypted ?? "Not provided"}

Return ONLY a valid JSON object (no markdown, no explanation) with this exact structure:
{
  "risks": [
    {
      "title": "Brief risk title",
      "description": "Clear description of the risk",
      "likelihood": <integer 1-5>,
      "impact": <integer 1-5>,
      "severity": "<low|medium|high|critical>",
      "mitigation": "Specific mitigation action"
    }
  ],
  "overall_risk_level": "<low|medium|high|critical>"
}

Likelihood scale: 1=Rare, 2=Unlikely, 3=Possible, 4=Likely, 5=Almost Certain
Impact scale: 1=Negligible, 2=Minor, 3=Moderate, 4=Major, 5=Catastrophic
Severity: likelihood × impact → 1-4=low, 5-9=medium, 10-16=high, 17-25=critical
Overall risk level = highest individual severity.`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: "application/json",
          },
        }),
      },
    );

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      return json(
        { error: `Gemini API error ${geminiRes.status}: ${errText}` },
        502,
      );
    }

    const geminiData = await geminiRes.json();
    const rawText: string | undefined =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawText) return json({ error: "Empty response from Gemini" }, 502);

    let parsed: { risks: unknown[]; overall_risk_level: string };
    try {
      parsed = JSON.parse(rawText);
    } catch {
      return json({ error: "Could not parse Gemini JSON response" }, 502);
    }

    // Ensure severity is consistent with computed score.
    const risks = (parsed.risks ?? []).map((r: unknown) => {
      const risk = r as Record<string, unknown>;
      const lh = Number(risk.likelihood ?? 3);
      const imp = Number(risk.impact ?? 3);
      return { ...risk, severity: severityForScore(lh, imp) };
    });

    const overallLevel = parsed.overall_risk_level ?? "medium";

    // ── Save to DB (pending approval) ─────────────────────────────────────
    const { data: saved, error: saveErr } = await supabaseUser
      .from("risk_assessments")
      .insert({
        decision_id,
        methodology: "ai",
        output_jsonb: { risks, overall_risk_level: overallLevel },
        overall_risk_level: overallLevel,
        provider: "google",
        model: "gemini-2.0-flash",
        status: "pending_approval",
      })
      .select()
      .single();

    if (saveErr) {
      return json({ error: `Failed to save: ${saveErr.message}` }, 500);
    }

    return json(saved);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
