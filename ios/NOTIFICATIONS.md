# iOS Notification System

## Overview

The Sit iOS app schedules random meditation prompt notifications throughout the day based on prompt settings configured in the web dashboard.

## Architecture

### NotificationService

`NotificationService.swift` handles all notification-related functionality:

- **Permission Management**: Requests and checks notification authorization status
- **Scheduling**: Schedules notifications based on `PromptSettings` from Convex
- **Random Distribution**: Distributes prompts evenly across waking hours with randomization

### Integration

1. **SitApp**: Requests notification permissions on app launch
2. **SyncViewModel**: Reschedules notifications whenever `PromptSettings` are synced from Convex
3. **Automatic Rescheduling**: Notifications are rescheduled every 30 seconds during sync

## Notification Scheduling Algorithm

The service divides the waking hours window into equal segments and places one notification randomly within each segment:

```
Waking Hours: 7am - 10pm (15 hours)
Prompts Per Day: 4
Segment Duration: 15 hours / 4 = 3.75 hours

Segment 1: 7:00am - 10:45am → Random time with ±30% variance
Segment 2: 10:45am - 2:30pm → Random time with ±30% variance
Segment 3: 2:30pm - 6:15pm → Random time with ±30% variance
Segment 4: 6:15pm - 10:00pm → Random time with ±30% variance
```

This ensures:
- Even distribution throughout the day
- Unpredictability to catch genuine state
- No clustering of prompts

## Notification Content

```json
{
  "title": "Meditation Check-in",
  "body": "In the View?",
  "sound": "default",
  "categoryIdentifier": "PROMPT_CATEGORY"
}
```

## Testing

### Manual Testing

1. **Launch the app** in the iOS Simulator
2. **Grant notification permission** when prompted
3. **Verify scheduling** by checking console logs for:
   - "📅 Scheduling N notifications between HH:00 and HH:00"
   - "✅ Scheduled notification N at YYYY-MM-DD HH:mm"

### Automated Testing

Run the test script:

```bash
cd ios
./test-notifications.sh
```

This script:
1. Boots the simulator
2. Builds and installs the app
3. Launches the app
4. Sends a test notification using `xcrun simctl push`
5. Verifies the notification appears

### Verify Scheduled Notifications

To see currently scheduled notifications, check the console logs after the app syncs:

```bash
xcrun simctl spawn <DEVICE_ID> log show --predicate 'process == "Sit"' --last 1m --info
```

Look for lines containing:
- "📅 Scheduling"
- "✅ Scheduled notification"
- "📱 Total notifications scheduled"

## Configuration

Prompt settings are configured via the web dashboard (`/`):

- **Prompts Per Day**: Number of random prompts (1-100)
- **Waking Hour Start**: Start of waking hours (0-23)
- **Waking Hour End**: End of waking hours (0-23)

Changes sync to iOS automatically every 30 seconds.

## Troubleshooting

### No notifications appearing

1. **Check permissions**: Ensure notification permission is granted
   - Settings → Notifications → Sit → Allow Notifications
2. **Check sync**: Verify app is syncing with Convex
   - Look for "✅ Sync complete" in console logs
3. **Check scheduling**: Verify notifications are being scheduled
   - Look for "📅 Scheduling" messages in logs

### Notifications not rescheduling

- Verify Convex is running at `http://127.0.0.1:3210`
- Check that prompt settings exist in Convex
- Ensure app has network access in simulator

### Test notification not appearing

- Ensure simulator is booted
- Verify bundle ID matches: `com.sit.app`
- Check notification permissions are granted

## Future Enhancements

- [ ] Interactive notification actions (Yes/No buttons)
- [ ] Deep linking to prompt response UI
- [ ] Notification history tracking
- [ ] Custom notification sounds
- [ ] Quiet hours override
