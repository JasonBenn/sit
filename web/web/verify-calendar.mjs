#!/usr/bin/env node
import { ConvexHttpClient } from "convex/browser";

const client = new ConvexHttpClient("http://127.0.0.1:3210");

async function verifyCalendar() {
  console.log("Verifying calendar functionality...\n");

  // Fetch meditation sessions
  const sessions = await client.query("meditationSessions:listMeditationSessions", {});
  console.log(`✓ Found ${sessions.length} meditation sessions`);

  // Convert to date strings
  const meditationDates = new Set(
    sessions.map(session => {
      const date = new Date(session.completedAt);
      return date.toISOString().split('T')[0];
    })
  );

  console.log("\nMeditation dates:");
  Array.from(meditationDates)
    .sort()
    .forEach(date => console.log(`  - ${date}`));

  // Calculate streak
  let streak = 0;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  let checkDate = new Date(today);

  while (true) {
    const dateStr = checkDate.toISOString().split('T')[0];
    if (meditationDates.has(dateStr)) {
      streak++;
      checkDate.setDate(checkDate.getDate() - 1);
    } else {
      break;
    }
  }

  console.log(`\n✓ Current streak: ${streak} days`);

  // Calculate yearly compliance
  const yearStart = new Date(new Date().getFullYear(), 0, 1);
  const now = new Date();
  now.setHours(23, 59, 59, 999);
  const daysSinceYearStart = Math.floor((now.getTime() - yearStart.getTime()) / (1000 * 60 * 60 * 24)) + 1;

  const meditationDaysThisYear = sessions.filter(session => {
    const sessionDate = new Date(session.completedAt);
    return sessionDate.getFullYear() === new Date().getFullYear();
  }).length;

  const percentage = Math.round((meditationDaysThisYear / daysSinceYearStart) * 100);

  console.log(`✓ Year compliance: ${percentage}% (${meditationDaysThisYear}/${daysSinceYearStart} days)`);

  if (percentage >= 75) {
    console.log("  🎯 On track for 75% goal!");
  } else {
    console.log(`  📊 ${75 - percentage}% below 75% goal`);
  }

  console.log("\n✅ Calendar verification complete!");
  console.log("\nTo manually verify:");
  console.log("1. Open http://localhost:5173 in your browser");
  console.log("2. Scroll to the 'Meditation Calendar' section");
  console.log("3. Verify the following:");
  console.log(`   - Current streak shows: ${streak} days`);
  console.log(`   - Year compliance shows: ${percentage}%`);
  console.log("   - Calendar has green days marked with checkmarks");
  console.log("   - Navigation buttons work (Previous/Next/Today)");
}

verifyCalendar().catch(console.error);
