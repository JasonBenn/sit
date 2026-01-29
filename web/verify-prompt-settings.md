# Verify Prompt Settings Feature

## Test Steps

1. Navigate to http://localhost:5173
2. Scroll to "Prompt Settings" section
3. Fill in form:
   - Prompts per day: 4
   - Waking hour start: 7
   - Waking hour end: 22
4. Click "Save Settings" button
5. Verify settings display shows: "4 prompts per day, 7:00 - 22:00"
6. Refresh the page
7. Verify settings still show: "4 prompts per day, 7:00 - 22:00"
8. Change settings:
   - Prompts per day: 6
   - Waking hour start: 6
   - Waking hour end: 23
9. Click "Save Settings"
10. Verify new settings display
11. Refresh and verify persistence

## Expected Results

- Form fields should accept valid input (numbers in range)
- Save button should update settings
- Settings should display below the form
- Settings should persist after page refresh
- Invalid values should be rejected (validation in handler)
