import "jsr:@supabase/functions-js/edge-runtime.d.ts";

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      decisionTitle,
      initialConfidence,
      finalScore,
      calibrationGap,
      outcomeState,
      riskLevel,
      lessonsList,
      duration,
    } = await req.json();

    if (!decisionTitle) return json({ error: "decisionTitle required" }, 400);

    const groqKey = Deno.env.get("GROQ_API_KEY");
    if (!groqKey) return json({ error: "GROQ_API_KEY not configured" }, 500);

    const systemPrompt =
      "You are an expert decision coach helping executives learn from their past decisions. " +
      "Be direct, specific, and constructive. Focus on actionable insights.";

    const lessonsText =
      lessonsList && lessonsList.length > 0
        ? lessonsList.map((l: string, i: number) => `${i + 1}. ${l}`).join("\n")
        : "No lessons recorded.";

    const userContent = `Analyse this closed decision and provide debrief insights.

Decision: ${decisionTitle}
Duration: ${duration ?? "Unknown"}
Outcome: ${outcomeState ?? "Unknown"}
Initial confidence: ${initialConfidence ?? "Unknown"}%
Final score: ${finalScore ?? "Unknown"}/100
Calibration gap: ${calibrationGap != null ? `${calibrationGap > 0 ? "+" : ""}${calibrationGap}` : "Unknown"} (positive = overconfident, negative = underconfident)
Risk level: ${riskLevel ?? "Unknown"}

Lessons recorded during the decision:
${lessonsText}

Return ONLY a valid JSON object (no markdown, no explanation) with this exact structure:
{
  "wentWell": ["string", "string", "string"],
  "improvements": ["string", "string", "string"],
  "summary": "Two to three sentence overall assessment of this decision and the key learning."
}

Rules:
- wentWell: exactly 3 specific things that went well or showed good decision-making
- improvements: exactly 3 specific, actionable things to do differently next time
- summary: honest overall assessment referencing calibration and outcome
- Be specific to this decision, not generic advice`;

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
            { role: "system", content: systemPrompt },
            { role: "user", content: userContent },
          ],
          temperature: 0.4,
          max_tokens: 800,
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

    let parsed: { wentWell: string[]; improvements: string[]; summary: string };
    try {
      parsed = JSON.parse(rawText);
    } catch {
      return json({ error: "Could not parse Groq JSON response" }, 502);
    }

    return json({
      wentWell: parsed.wentWell ?? [],
      improvements: parsed.improvements ?? [],
      summary: parsed.summary ?? "",
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
