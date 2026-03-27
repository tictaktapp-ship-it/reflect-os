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
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization" }, 401);

    const body = await req.json();
    const { content, content_type, mode, categories } = body;

    if (!content || typeof content !== "string") {
      return json({ error: "content (string) required" }, 400);
    }

    const validTypes = ["text", "url", "transcript"];
    const resolvedType = validTypes.includes(content_type) ? content_type : "text";

    const groqKey = Deno.env.get("GROQ_API_KEY");
    if (!groqKey) return json({ error: "GROQ_API_KEY not configured" }, 500);

    const categoryList = Array.isArray(categories)
      ? categories.map((c: { name: string }) => c.name).join(", ")
      : "";

    const multiple = mode === "multiple";

    const contentTypeLabel: Record<string, string> = {
      text: "document or text",
      url: "web page content",
      transcript: "meeting transcript",
    };

    const systemPrompt =
      "You are an expert at identifying and extracting key decisions from business content. " +
      "Return only valid JSON with no markdown or explanation.";

    const userContent = multiple
      ? `Extract all decisions made, discussed, or implied in the following ${contentTypeLabel[resolvedType]}.\n\n` +
        (categoryList ? `Available categories: ${categoryList}\n\n` : "") +
        `Content:\n${content}\n\n` +
        `Return ONLY valid JSON with this structure:\n` +
        `{\n` +
        `  "decisions": [\n` +
        `    {\n` +
        `      "title": "Short decision title",\n` +
        `      "description": "What was decided and key rationale",\n` +
        `      "stakes": "Why this matters / consequences",\n` +
        `      "category": "Category name from the list above, or null"\n` +
        `    }\n` +
        `  ]\n` +
        `}`
      : `Extract the single most significant decision from the following ${contentTypeLabel[resolvedType]}.\n\n` +
        (categoryList ? `Available categories: ${categoryList}\n\n` : "") +
        `Content:\n${content}\n\n` +
        `Return ONLY valid JSON with this structure:\n` +
        `{\n` +
        `  "decisions": [\n` +
        `    {\n` +
        `      "title": "Short decision title",\n` +
        `      "description": "What was decided and key rationale",\n` +
        `      "stakes": "Why this matters / consequences",\n` +
        `      "category": "Category name from the list above, or null"\n` +
        `    }\n` +
        `  ]\n` +
        `}`;

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
          temperature: 0.2,
          max_tokens: 2000,
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

    // Strip any markdown fences the model may have added.
    const cleaned = rawText.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/i, "").trim();

    let parsed: { decisions: unknown[] };
    try {
      parsed = JSON.parse(cleaned);
    } catch {
      return json({ error: "Could not parse Groq JSON response" }, 502);
    }

    if (!Array.isArray(parsed.decisions) || parsed.decisions.length === 0) {
      return json({ error: "No decisions found in the content" }, 422);
    }

    return json({ decisions: parsed.decisions });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
