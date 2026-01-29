#!/usr/bin/env node
import { ConvexHttpClient } from "convex/browser";

const client = new ConvexHttpClient(process.env.VITE_CONVEX_URL);

async function createTestData() {
  console.log("Creating test prompt response data...");

  const now = Date.now();
  const oneDay = 24 * 60 * 60 * 1000;

  // Create data for the last 60 days
  const testData = [];

  for (let daysAgo = 0; daysAgo < 60; daysAgo++) {
    const date = new Date(now - daysAgo * oneDay);

    // Random number of prompts per day (1-6)
    const promptsPerDay = Math.floor(Math.random() * 6) + 1;

    for (let i = 0; i < promptsPerDay; i++) {
      // Random time during the day (7am to 10pm)
      const randomHour = 7 + Math.floor(Math.random() * 15);
      const randomMinute = Math.floor(Math.random() * 60);
      date.setHours(randomHour, randomMinute, 0, 0);

      // 70% chance of being "in the view" (yes)
      const inTheView = Math.random() < 0.7;

      testData.push({
        inTheView,
        respondedAt: date.getTime()
      });
    }
  }

  // Insert all test data
  for (const data of testData) {
    await client.mutation("promptResponses:logPromptResponse", data);
  }

  console.log(`✅ Created ${testData.length} test prompt responses`);

  // Show some statistics
  const yesCount = testData.filter(d => d.inTheView).length;
  const percentage = Math.round((yesCount / testData.length) * 100);
  console.log(`   Overall: ${percentage}% in the view (${yesCount}/${testData.length})`);
}

createTestData().catch(console.error);
