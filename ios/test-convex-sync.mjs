#!/usr/bin/env node

/**
 * Test script to verify iOS app can sync with Convex
 * Simulates what the iOS app does: fetch beliefs, presets, settings, and log events
 */

const CONVEX_URL = "http://127.0.0.1:3210";

async function convexQuery(functionPath, args = {}) {
  const response = await fetch(`${CONVEX_URL}/api/query`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      path: functionPath,
      args: [args],
    }),
  });

  if (!response.ok) {
    throw new Error(`Query failed: ${response.status} ${response.statusText}`);
  }

  const data = await response.json();
  return data.value;
}

async function convexMutation(functionPath, args = {}) {
  const response = await fetch(`${CONVEX_URL}/api/mutation`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      path: functionPath,
      args: [args],
    }),
  });

  if (!response.ok) {
    throw new Error(`Mutation failed: ${response.status} ${response.statusText}`);
  }

  const data = await response.json();
  return data.value;
}

async function testSync() {
  console.log("🧪 Testing iOS → Convex Sync\n");

  try {
    // Test 1: Fetch beliefs
    console.log("1️⃣ Fetching beliefs...");
    const beliefs = await convexQuery("beliefs:listBeliefs");
    console.log(`   ✅ Got ${beliefs.length} beliefs`);
    if (beliefs.length > 0) {
      console.log(`   📝 Example: "${beliefs[0].text.substring(0, 50)}..."`);
    }

    // Test 2: Fetch timer presets
    console.log("\n2️⃣ Fetching timer presets...");
    const presets = await convexQuery("timerPresets:listTimerPresets");
    console.log(`   ✅ Got ${presets.length} presets`);
    if (presets.length > 0) {
      const preset = presets[0];
      const label = preset.label ? ` (${preset.label})` : "";
      console.log(`   ⏱️  Example: ${preset.durationMinutes} min${label}`);
    }

    // Test 3: Fetch prompt settings
    console.log("\n3️⃣ Fetching prompt settings...");
    const settings = await convexQuery("promptSettings:getPromptSettings");
    if (settings) {
      console.log(`   ✅ Got settings`);
      console.log(`   🔔 Prompts per day: ${settings.promptsPerDay}`);
      console.log(`   🌅 Waking hours: ${settings.wakingHourStart}:00 - ${settings.wakingHourEnd}:00`);
    } else {
      console.log(`   ⚠️  No prompt settings found (this is OK for initial setup)`);
    }

    // Test 4: Log a test meditation session
    console.log("\n4️⃣ Logging test meditation session...");
    const now = Date.now();
    const sessionId = await convexMutation("meditationSessions:logMeditationSession", {
      durationMinutes: 5,
      startedAt: now - (5 * 60 * 1000),
      completedAt: now,
      hasInnerTimers: false,
    });
    console.log(`   ✅ Created session: ${sessionId}`);

    // Test 5: Log a test prompt response
    console.log("\n5️⃣ Logging test prompt response...");
    const responseId = await convexMutation("promptResponses:logPromptResponse", {
      inTheView: true,
      respondedAt: Date.now(),
    });
    console.log(`   ✅ Created response: ${responseId}`);

    // Test 6: Verify logged data appears in queries
    console.log("\n6️⃣ Verifying logged data...");
    const sessions = await convexQuery("meditationSessions:listMeditationSessions", { limit: 1 });
    console.log(`   ✅ Latest session: ${sessions[0].durationMinutes} min`);

    console.log("\n✅ All tests passed! iOS app should sync correctly.\n");

    return true;
  } catch (error) {
    console.error("\n❌ Test failed:", error.message);
    console.error("\n💡 Make sure Convex dev server is running:");
    console.error("   cd ../web && npx convex dev\n");
    return false;
  }
}

// Run tests
testSync().then((success) => {
  process.exit(success ? 0 : 1);
});
