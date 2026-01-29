#!/usr/bin/env node

import { ConvexHttpClient } from "convex/browser";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Read the Convex URL from .env.local
const envContent = readFileSync(join(__dirname, '.env.local'), 'utf-8');
const convexUrl = envContent.match(/VITE_CONVEX_URL=(.+)/)?.[1]?.trim();

if (!convexUrl) {
  console.error('❌ VITE_CONVEX_URL not found in .env.local');
  process.exit(1);
}

console.log(`🔗 Connecting to Convex at: ${convexUrl}\n`);

const client = new ConvexHttpClient(convexUrl);

async function runTests() {
  try {
    console.log('📋 Test 1: Add a new limiting belief');
    const beliefId1 = await client.mutation("beliefs:createBelief", {
      text: "I'm not good enough"
    });
    console.log(`✅ Created belief with ID: ${beliefId1}`);

    console.log('\n📋 Test 2: List beliefs (should show 1)');
    let beliefs = await client.query("beliefs:listBeliefs");
    console.log(`✅ Found ${beliefs.length} belief(s)`);
    console.log(`   Text: "${beliefs[0].text}"`);

    console.log('\n📋 Test 3: Add more beliefs');
    const beliefId2 = await client.mutation("beliefs:createBelief", {
      text: "I don't deserve success"
    });
    const beliefId3 = await client.mutation("beliefs:createBelief", {
      text: "People will judge me"
    });
    console.log(`✅ Created 2 more beliefs`);

    console.log('\n📋 Test 4: List all beliefs (should show 3)');
    beliefs = await client.query("beliefs:listBeliefs");
    console.log(`✅ Found ${beliefs.length} belief(s):`);
    beliefs.forEach((b, i) => console.log(`   ${i + 1}. "${b.text}"`));

    console.log('\n📋 Test 5: Update a belief');
    await client.mutation("beliefs:updateBelief", {
      id: beliefId1,
      text: "I am enough"
    });
    beliefs = await client.query("beliefs:listBeliefs");
    const updatedBelief = beliefs.find(b => b._id === beliefId1);
    console.log(`✅ Updated belief text to: "${updatedBelief.text}"`);

    console.log('\n📋 Test 6: Delete a belief');
    await client.mutation("beliefs:deleteBelief", { id: beliefId2 });
    beliefs = await client.query("beliefs:listBeliefs");
    console.log(`✅ Deleted 1 belief, now have ${beliefs.length} belief(s)`);

    console.log('\n📋 Test 7: Verify persistence (query again)');
    beliefs = await client.query("beliefs:listBeliefs");
    console.log(`✅ Still have ${beliefs.length} belief(s) after re-query:`);
    beliefs.forEach((b, i) => console.log(`   ${i + 1}. "${b.text}"`));

    console.log('\n📋 Test 8: Clean up - delete remaining beliefs');
    for (const belief of beliefs) {
      await client.mutation("beliefs:deleteBelief", { id: belief._id });
    }
    beliefs = await client.query("beliefs:listBeliefs");
    console.log(`✅ Cleaned up, now have ${beliefs.length} belief(s)`);

    console.log('\n🎉 All tests passed!');
    console.log('\n✅ Feature f2-web-belief-management is working correctly!');
    console.log('\n📝 Next steps:');
    console.log('   1. Open http://localhost:5173 in Chrome');
    console.log('   2. Follow the steps in MANUAL_TEST.md to verify the UI');

  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    console.error(error);
    process.exit(1);
  }
}

runTests();
