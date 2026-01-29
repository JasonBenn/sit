#!/usr/bin/env node
/**
 * Chrome automation test for View Statistics feature (f6-web-view-stats)
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

const APP_URL = 'http://localhost:5173';

async function runChromeCommand(tool, args) {
  const cmd = `claude mcp call claude-in-chrome ${tool} '${JSON.stringify(args)}'`;
  try {
    const { stdout } = await execAsync(cmd);
    return JSON.parse(stdout);
  } catch (error) {
    console.error(`Error running ${tool}:`, error.message);
    throw error;
  }
}

async function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function testViewStatsUI() {
  console.log('🧪 Testing View Statistics UI (f6-web-view-stats)...\n');

  try {
    // Step 1: Get current tabs
    console.log('1. Getting current browser tabs...');
    const tabsContext = await runChromeCommand('tabs_context_mcp', {});
    console.log(`   Found ${tabsContext.tabs?.length || 0} tabs`);

    // Step 2: Create a new tab for testing
    console.log('\n2. Creating new tab and navigating to app...');
    const newTab = await runChromeCommand('tabs_create_mcp', { url: APP_URL });
    const tabId = newTab.tabId;
    console.log(`   Created tab ${tabId}`);

    // Wait for page to load
    await wait(3000);

    // Step 3: Scroll to View Statistics section
    console.log('\n3. Scrolling to View Statistics section...');
    await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const heading = Array.from(document.querySelectorAll('h2')).find(h => h.textContent === 'View Statistics');
        if (heading) {
          heading.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      `
    });
    await wait(1000);

    // Step 4: Check overall percentage is displayed
    console.log('\n4. Checking overall View % statistic...');
    const overallStat = await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const el = document.querySelector('[data-testid="overall-percentage"]');
        if (!el) throw new Error('Overall percentage not found');
        {
          text: el.textContent.trim(),
          displayed: el.offsetParent !== null
        }
      `
    });
    console.log(`   ✅ Overall View %: ${overallStat.result.text}`);

    // Step 5: Check overall counts are displayed
    const overallCounts = await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const el = document.querySelector('[data-testid="overall-counts"]');
        if (!el) throw new Error('Overall counts not found');
        el.textContent.trim()
      `
    });
    console.log(`   ✅ Counts: ${overallCounts.result}`);

    // Step 6: Verify daily view is default
    console.log('\n5. Checking daily view is displayed by default...');
    const dailyTable = await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const table = document.querySelector('[data-testid="daily-stats-table"]');
        if (!table) throw new Error('Daily stats table not found');
        const rows = table.querySelectorAll('tbody tr');
        {
          rowCount: rows.length,
          hasHeaders: !!table.querySelector('thead'),
          displayed: table.offsetParent !== null
        }
      `
    });
    console.log(`   ✅ Daily table: ${dailyTable.result.rowCount} rows`);

    // Step 7: Click weekly button
    console.log('\n6. Switching to weekly view...');
    await runChromeCommand('click', {
      tabId,
      selector: '[data-testid="weekly-button"]'
    });
    await wait(500);

    const weeklyTable = await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const table = document.querySelector('[data-testid="weekly-stats-table"]');
        if (!table) throw new Error('Weekly stats table not found');
        const rows = table.querySelectorAll('tbody tr');
        {
          rowCount: rows.length,
          displayed: table.offsetParent !== null
        }
      `
    });
    console.log(`   ✅ Weekly table: ${weeklyTable.result.rowCount} rows`);

    // Step 8: Click monthly button
    console.log('\n7. Switching to monthly view...');
    await runChromeCommand('click', {
      tabId,
      selector: '[data-testid="monthly-button"]'
    });
    await wait(500);

    const monthlyTable = await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const table = document.querySelector('[data-testid="monthly-stats-table"]');
        if (!table) throw new Error('Monthly stats table not found');
        const rows = table.querySelectorAll('tbody tr');
        {
          rowCount: rows.length,
          displayed: table.offsetParent !== null
        }
      `
    });
    console.log(`   ✅ Monthly table: ${monthlyTable.result.rowCount} rows`);

    // Step 9: Switch back to daily and test day selector
    console.log('\n8. Switching back to daily and testing day selector...');
    await runChromeCommand('click', {
      tabId,
      selector: '[data-testid="daily-button"]'
    });
    await wait(500);

    await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const select = document.querySelector('[data-testid="days-select"]');
        if (!select) throw new Error('Days select not found');
        select.value = '7';
        select.dispatchEvent(new Event('change', { bubbles: true }));
      `
    });
    await wait(500);

    const dailyTable7Days = await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const table = document.querySelector('[data-testid="daily-stats-table"]');
        if (!table) throw new Error('Daily stats table not found');
        const rows = table.querySelectorAll('tbody tr');
        rows.length
      `
    });
    console.log(`   ✅ Daily table with 7-day filter: ${dailyTable7Days.result} rows (max)`);

    // Step 10: Take screenshot
    console.log('\n9. Taking screenshot...');
    await runChromeCommand('screenshot_tool', {
      tabId,
      path: 'view-stats-screenshot.png'
    });
    console.log('   ✅ Screenshot saved: view-stats-screenshot.png');

    // Step 11: Verify calculations
    console.log('\n10. Verifying percentage calculations...');
    const sampleDay = await runChromeCommand('javascript_tool', {
      tabId,
      code: `
        const table = document.querySelector('[data-testid="daily-stats-table"]');
        if (!table) throw new Error('Daily stats table not found');
        const firstRow = table.querySelector('tbody tr');
        if (!firstRow) throw new Error('No data rows found');

        const cells = firstRow.querySelectorAll('td');
        const date = cells[0].textContent.trim();
        const percentage = cells[1].textContent.trim();
        const responses = cells[2].textContent.trim();

        // Parse "yes/total" format
        const [yes, total] = responses.split('/').map(s => parseInt(s.trim()));
        const calculatedPercentage = Math.round((yes / total) * 100);
        const displayedPercentage = parseInt(percentage);

        {
          date,
          displayed: displayedPercentage,
          calculated: calculatedPercentage,
          matches: displayedPercentage === calculatedPercentage,
          yes,
          total
        }
      `
    });

    if (sampleDay.result.matches) {
      console.log(`   ✅ Calculation verified: ${sampleDay.result.yes}/${sampleDay.result.total} = ${sampleDay.result.displayed}%`);
    } else {
      console.error(`   ❌ Calculation error: Expected ${sampleDay.result.calculated}%, got ${sampleDay.result.displayed}%`);
      throw new Error('Percentage calculation mismatch');
    }

    console.log('\n✅ All View Statistics tests passed!\n');
    console.log('Feature verification complete:');
    console.log('  ✓ Overall View % displayed');
    console.log('  ✓ Daily view works');
    console.log('  ✓ Weekly view works');
    console.log('  ✓ Monthly view works');
    console.log('  ✓ Day range selector works');
    console.log('  ✓ Percentage calculations accurate');
    console.log('  ✓ Time range switching functional');

    return true;
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    throw error;
  }
}

// Run the test
testViewStatsUI()
  .then(() => {
    console.log('\n🎉 f6-web-view-stats: PASSED');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 f6-web-view-stats: FAILED');
    console.error(error);
    process.exit(1);
  });
