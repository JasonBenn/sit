#!/usr/bin/env node
import { ConvexHttpClient } from "convex/browser";

const client = new ConvexHttpClient("http://127.0.0.1:3210");

// Create test meditation sessions for the past month with a streak pattern
async function createTestSessions() {
  const now = new Date();
  const sessions = [];

  // Create a 5-day streak ending today
  for (let i = 0; i < 5; i++) {
    const date = new Date(now);
    date.setDate(date.getDate() - i);
    date.setHours(10, 0, 0, 0);

    sessions.push({
      durationMinutes: 20,
      startedAt: date.getTime(),
      completedAt: date.getTime() + 20 * 60 * 1000,
    });
  }

  // Add some scattered sessions earlier in the month
  const daysAgo = [7, 8, 10, 15, 20, 25];
  for (const days of daysAgo) {
    const date = new Date(now);
    date.setDate(date.getDate() - days);
    date.setHours(9, 0, 0, 0);

    sessions.push({
      durationMinutes: 30,
      startedAt: date.getTime(),
      completedAt: date.getTime() + 30 * 60 * 1000,
    });
  }

  console.log(`Creating ${sessions.length} test meditation sessions...`);

  for (const session of sessions) {
    try {
      await client.mutation("meditationSessions:logMeditationSession", session);
      const date = new Date(session.completedAt).toISOString().split('T')[0];
      console.log(`✓ Created session for ${date}`);
    } catch (error) {
      console.error(`✗ Failed to create session:`, error.message);
    }
  }

  console.log("\nTest data created successfully!");
  console.log("Current streak should be: 5 days");

  // Calculate expected compliance
  const yearStart = new Date(now.getFullYear(), 0, 1);
  const daysSinceYearStart = Math.floor((now.getTime() - yearStart.getTime()) / (1000 * 60 * 60 * 24)) + 1;
  const expectedCompliance = Math.round((sessions.length / daysSinceYearStart) * 100);
  console.log(`Year compliance should be approximately: ${expectedCompliance}%`);
}

createTestSessions().catch(console.error);
