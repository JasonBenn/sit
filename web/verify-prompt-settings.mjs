#!/usr/bin/env node
/**
 * Verification script for f4-web-prompt-settings
 * Tests that prompt settings can be created, updated, and retrieved
 */

import { ConvexHttpClient } from 'convex/browser'
import { api } from './convex/_generated/api.js'

const DEPLOYMENT_URL = process.env.CONVEX_URL || 'http://127.0.0.1:3210'
const client = new ConvexHttpClient(DEPLOYMENT_URL)

async function verify() {
  console.log('🔍 Verifying f4-web-prompt-settings...\n')

  try {
    // Test 1: Create/Update initial settings
    console.log('Test 1: Creating initial prompt settings (4 prompts, 7-22 hours)...')
    await client.mutation(api.promptSettings.updatePromptSettings, {
      promptsPerDay: 4,
      wakingHourStart: 7,
      wakingHourEnd: 22,
    })
    console.log('✅ Settings created/updated\n')

    // Test 2: Read settings
    console.log('Test 2: Reading prompt settings...')
    const settings1 = await client.query(api.promptSettings.getPromptSettings)

    if (!settings1) {
      throw new Error('No settings found after creation')
    }

    console.log('Settings retrieved:', {
      promptsPerDay: settings1.promptsPerDay,
      wakingHourStart: settings1.wakingHourStart,
      wakingHourEnd: settings1.wakingHourEnd,
    })

    if (settings1.promptsPerDay !== 4) {
      throw new Error(`Expected promptsPerDay=4, got ${settings1.promptsPerDay}`)
    }
    if (settings1.wakingHourStart !== 7) {
      throw new Error(`Expected wakingHourStart=7, got ${settings1.wakingHourStart}`)
    }
    if (settings1.wakingHourEnd !== 22) {
      throw new Error(`Expected wakingHourEnd=22, got ${settings1.wakingHourEnd}`)
    }
    console.log('✅ Settings verified\n')

    // Test 3: Update settings
    console.log('Test 3: Updating settings (6 prompts, 6-23 hours)...')
    await client.mutation(api.promptSettings.updatePromptSettings, {
      promptsPerDay: 6,
      wakingHourStart: 6,
      wakingHourEnd: 23,
    })
    console.log('✅ Settings updated\n')

    // Test 4: Verify update persisted
    console.log('Test 4: Verifying updated settings...')
    const settings2 = await client.query(api.promptSettings.getPromptSettings)

    console.log('Updated settings:', {
      promptsPerDay: settings2.promptsPerDay,
      wakingHourStart: settings2.wakingHourStart,
      wakingHourEnd: settings2.wakingHourEnd,
    })

    if (settings2.promptsPerDay !== 6) {
      throw new Error(`Expected promptsPerDay=6, got ${settings2.promptsPerDay}`)
    }
    if (settings2.wakingHourStart !== 6) {
      throw new Error(`Expected wakingHourStart=6, got ${settings2.wakingHourStart}`)
    }
    if (settings2.wakingHourEnd !== 23) {
      throw new Error(`Expected wakingHourEnd=23, got ${settings2.wakingHourEnd}`)
    }
    console.log('✅ Updated settings verified\n')

    // Test 5: Verify updatedAt timestamp changed
    console.log('Test 5: Verifying updatedAt timestamp...')
    if (settings2.updatedAt <= settings1.updatedAt) {
      throw new Error('updatedAt timestamp did not increase after update')
    }
    console.log('✅ Timestamp updated correctly\n')

    console.log('✨ All tests passed! f4-web-prompt-settings is working correctly.\n')
    console.log('📋 Manual UI verification steps:')
    console.log('   1. Open http://localhost:5173 in your browser')
    console.log('   2. Scroll to "Prompt Settings" section')
    console.log('   3. Verify current settings display: "6 prompts per day, 6:00 - 23:00"')
    console.log('   4. Change values in the form and click "Save Settings"')
    console.log('   5. Refresh the page and verify settings persist\n')

  } catch (error) {
    console.error('❌ Verification failed:', error.message)
    process.exit(1)
  }
}

verify()
