const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Anthropic = require("@anthropic-ai/sdk");

// Store API key as a Firebase secret: firebase functions:secrets:set ANTHROPIC_API_KEY
const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

/**
 * askForkBook — conversational restaurant discovery powered by Claude
 *
 * Input:
 *   question: string         — the user's natural language question
 *   context: {
 *     userName: string
 *     tastePrefs: { favoriteCuisines: string[], diningFrequency: string }
 *     myRestaurants: [{ name, cuisine, reaction, dishes: [{ name, liked }], dateVisited }]
 *     tableRestaurants: [{ name, cuisine, rating, userName, dishes, dateVisited }]
 *     members: [{ name }]
 *   }
 *
 * Returns:
 *   answer: string           — Claude's response
 *   suggestions: [{ name, reason }]  — optional structured restaurant suggestions
 */
exports.askForkBook = onCall(
  { secrets: [anthropicKey], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    // Auth check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const { question, context } = request.data;
    if (!question || typeof question !== "string" || question.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Question is required");
    }

    // Build the system prompt with user context
    const systemPrompt = buildSystemPrompt(context);

    const client = new Anthropic({ apiKey: anthropicKey.value() });

    try {
      const message = await client.messages.create({
        model: "claude-sonnet-4-20250514",
        max_tokens: 600,
        system: systemPrompt,
        messages: [{ role: "user", content: question.trim() }],
      });

      const answer = message.content
        .filter((b) => b.type === "text")
        .map((b) => b.text)
        .join("\n");

      // Try to extract structured suggestions from the response
      const suggestions = extractSuggestions(answer, context);

      return { answer, suggestions };
    } catch (err) {
      console.error("Claude API error:", err);
      throw new HttpsError("internal", "Failed to get recommendation");
    }
  }
);

function buildSystemPrompt(ctx) {
  if (!ctx) return fallbackPrompt();

  const parts = [
    `You are ForkBook, a personal restaurant concierge for ${ctx.userName || "the user"}.`,
    "You help them discover where to eat based on their taste and their trusted friends' experiences.",
    "Be warm, concise (2-4 sentences per suggestion), and opinionated — like a foodie friend, not a search engine.",
    "Always ground your suggestions in the data provided. If you don't have relevant data, say so honestly.",
    "Never invent restaurants or dishes that aren't in the context below.",
    "Format: Give 1-3 suggestions max. For each, mention the restaurant name, why it fits, and a specific dish to try if known.",
    "",
  ];

  // Taste preferences
  if (ctx.tastePrefs) {
    const cuisines = ctx.tastePrefs.favoriteCuisines || [];
    const freq = ctx.tastePrefs.diningFrequency || "";
    if (cuisines.length > 0) {
      parts.push(`Their favorite cuisines (ranked): ${cuisines.join(", ")}.`);
    }
    if (freq) {
      parts.push(`They dine out: ${freq}.`);
    }
  }

  // User's own restaurants
  if (ctx.myRestaurants && ctx.myRestaurants.length > 0) {
    parts.push("");
    parts.push(`THEIR RESTAURANT HISTORY (${ctx.myRestaurants.length} places):`);
    for (const r of ctx.myRestaurants.slice(0, 30)) {
      const reaction = r.reaction || "";
      const dishStr =
        r.dishes && r.dishes.length > 0
          ? ` — dishes: ${r.dishes.map((d) => `${d.name}${d.liked ? " (👍)" : " (👎)"}`).join(", ")}`
          : "";
      const date = r.dateVisited ? ` (${r.dateVisited})` : "";
      parts.push(`• ${r.name} [${r.cuisine}] ${reaction}${date}${dishStr}`);
    }
  }

  // Table members' restaurants
  if (ctx.tableRestaurants && ctx.tableRestaurants.length > 0) {
    parts.push("");
    parts.push(
      `THEIR TABLE'S RESTAURANTS (friends' visits, ${ctx.tableRestaurants.length} entries):`
    );
    for (const r of ctx.tableRestaurants.slice(0, 40)) {
      const who = r.userName || "Friend";
      const rating = r.rating >= 5 ? "❤️" : r.rating >= 3 ? "👍" : "😐";
      const dishStr =
        r.dishes && r.dishes.length > 0
          ? ` — ${r.dishes.map((d) => d.name).join(", ")}`
          : "";
      const date = r.dateVisited ? ` (${r.dateVisited})` : "";
      parts.push(`• ${r.name} [${r.cuisine}] ${rating} by ${who}${date}${dishStr}`);
    }
  }

  // Members
  if (ctx.members && ctx.members.length > 0) {
    parts.push("");
    parts.push(
      `Table members: ${ctx.members.map((m) => m.name).join(", ")}`
    );
  }

  return parts.join("\n");
}

function fallbackPrompt() {
  return [
    "You are ForkBook, a personal restaurant concierge.",
    "The user hasn't logged many restaurants yet.",
    "Encourage them to log visits and invite friends to get personalized recommendations.",
    "Be warm and brief.",
  ].join("\n");
}

function extractSuggestions(answer, context) {
  // Simple extraction: find restaurant names from context that appear in the answer
  const suggestions = [];
  const allNames = new Set();

  if (context?.myRestaurants) {
    context.myRestaurants.forEach((r) => allNames.add(r.name));
  }
  if (context?.tableRestaurants) {
    context.tableRestaurants.forEach((r) => allNames.add(r.name));
  }

  for (const name of allNames) {
    if (answer.includes(name) && suggestions.length < 3) {
      // Find the sentence containing this restaurant
      const sentences = answer.split(/[.!]\s/);
      const relevant = sentences.find((s) => s.includes(name)) || "";
      suggestions.push({ name, reason: relevant.trim() });
    }
  }

  return suggestions;
}
