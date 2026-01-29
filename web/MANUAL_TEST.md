# Manual Testing Guide for f2-web-belief-management

## Prerequisites
1. Convex dev server running: `npx convex dev` (should be at http://127.0.0.1:3210)
2. Vite dev server running: `pnpm dev` (should be at http://localhost:5173)

## Test Steps

### 1. Navigate to Web App
- Open Chrome and go to http://localhost:5173
- **Expected**: Page loads showing "Sit - Meditation Tracker" header
- **Expected**: "Limiting Beliefs" section is visible
- **Expected**: Input field with placeholder "Enter a limiting belief..." and "Add Belief" button

### 2. Add a New Limiting Belief
- Type "I'm not good enough" in the input field
- Click "Add Belief" button
- **Expected**: Belief appears in the list below
- **Expected**: Input field clears
- **Expected**: "Empty state" message is gone

### 3. Add Multiple Beliefs
- Add "I don't deserve success"
- Add "People will judge me"
- **Expected**: All three beliefs are visible in the list
- **Expected**: Each belief has "Edit" and "Delete" buttons

### 4. Edit an Existing Belief
- Click "Edit" button on the first belief ("I'm not good enough")
- **Expected**: Belief text becomes an editable input field
- **Expected**: "Save" and "Cancel" buttons appear
- Change text to "I am enough"
- Click "Save" button
- **Expected**: Belief updates with new text
- **Expected**: Edit mode exits, showing normal view with "Edit" and "Delete" buttons

### 5. Cancel Edit
- Click "Edit" on any belief
- Make changes to the text
- Click "Cancel" button
- **Expected**: Changes are discarded
- **Expected**: Original text is still displayed

### 6. Delete a Belief
- Click "Delete" button on one belief
- **Expected**: Browser confirmation dialog appears
- Click "OK" to confirm
- **Expected**: Belief is removed from the list
- **Expected**: Remaining beliefs are still visible

### 7. Verify Changes Persist on Refresh
- Note the current list of beliefs
- Refresh the page (Cmd+R or F5)
- **Expected**: Page reloads
- **Expected**: All beliefs are still present with the same text
- **Expected**: Changes from previous edits are preserved

### 8. Empty State
- Delete all remaining beliefs
- **Expected**: "No limiting beliefs yet. Add one above to get started." message appears
- **Expected**: List is empty but UI is still functional

### 9. Re-add After Empty
- Add a new belief
- **Expected**: Empty state disappears
- **Expected**: New belief appears in the list

## Test Results

All steps completed successfully: ✓

## Notes
- The UI uses Convex for real-time data sync
- Changes are persisted to the local Convex backend
- The app should handle network latency gracefully (shows "Loading..." state initially)
