# Watch Complication Setup Guide

This guide explains how to configure the Sit Watch app complication (widget) in Xcode.

## Overview

The meditation status complication shows whether you've meditated today:
- **Done**: Green background with checkmark ✓
- **Not Done**: Gray background with empty circle ○

## Implementation

The complication is implemented in `SitWatch/MeditationStatusWidget.swift` using WidgetKit (watchOS 9+).

### Key Components

1. **MeditationStorage** - Shared storage utility
   - `recordMeditation()` - Saves current date when meditation is logged
   - `didMeditateToday()` - Checks if meditation was logged today
   - Uses `UserDefaults.standard` with key `"lastMeditationDate"`

2. **MeditationStatusWidget** - WidgetKit widget
   - Supports all watchOS complication families:
     - `.accessoryCircular` - Round complication (most common)
     - `.accessoryRectangular` - Large rectangular complication
     - `.accessoryInline` - Text-only inline complication
     - `.accessoryCorner` - Corner complication
   - Updates automatically at midnight each day
   - Tapping opens the Sit Watch app

3. **WatchViewModel Integration**
   - `logMeditationSession()` now calls `MeditationStorage.recordMeditation()`
   - Automatically reloads widget timelines after logging session

## Xcode Configuration Required

⚠️ **IMPORTANT**: The widget code has been created, but you must add it to the Xcode project to enable complications.

### Option 1: Add Widget to Existing Watch App (Recommended for watchOS 9+)

For watchOS 9 and later, you can include the widget directly in the Watch app target without creating a separate extension.

1. Open `Sit.xcodeproj` in Xcode
2. Select the `SitWatch` target
3. Go to **Signing & Capabilities**
4. Ensure **WidgetKit Extension** capability is added (if not, click **+ Capability** and add it)
5. In **Info.plist**, add:
   ```xml
   <key>NSSupportsLiveActivities</key>
   <false/>
   <key>CLKComplicationSupportedFamilies</key>
   <array>
       <string>CLKComplicationFamilyCircularSmall</string>
       <string>CLKComplicationFamilyModularSmall</string>
       <string>CLKComplicationFamilyModularLarge</string>
       <string>CLKComplicationFamilyUtilitarianSmall</string>
       <string>CLKComplicationFamilyUtilitarianLarge</string>
       <string>CLKComplicationFamilyGraphicCorner</string>
       <string>CLKComplicationFamilyGraphicCircular</string>
       <string>CLKComplicationFamilyGraphicRectangular</string>
   </array>
   ```
6. Build and run the Watch app

### Option 2: Create Widget Extension Target (For watchOS 8 or earlier)

If targeting watchOS 8 or earlier, you need a separate Widget Extension:

1. Open `Sit.xcodeproj` in Xcode
2. Go to **File > New > Target**
3. Select **watchOS** > **Widget Extension**
4. Name it `SitWatchWidget`
5. Set the following:
   - Bundle ID: `com.yourcompany.Sit.watchkitapp.SitWatchWidget`
   - Include Configuration Intent: **No**
6. Click **Finish**
7. Delete the generated `SitWatchWidget.swift` file
8. Add `MeditationStatusWidget.swift` to the new target
9. Ensure the widget extension embeds in `SitWatch.app`
10. Build and run

## Testing the Complication

### In Simulator

1. Build and run the Watch app in Xcode
2. Open the Watch face editor:
   - Force press (click + hold) on the watch face
   - Tap **Edit**
3. Swipe to **Complications** settings
4. Tap a complication slot
5. Scroll to find **Sit** under available complications
6. Select a complication style (Circular, Rectangular, etc.)
7. Press the Digital Crown to exit edit mode

### On Physical Device

1. Build and install the app on your Apple Watch
2. On the watch, force press the watch face
3. Tap **Customize**
4. Swipe to complications
5. Tap a complication slot and select **Sit**
6. Choose your preferred style

### Verifying Behavior

**Before Meditation:**
- Complication shows gray background
- Icon is an empty circle (○)
- Text shows "Not yet" or "Sit"

**After Meditation:**
1. Start a meditation timer in the app
2. Let it complete (or use Test tab to log a session)
3. Watch the complication update:
   - Background turns green
   - Icon becomes a checkmark (✓)
   - Text shows "Done today" or "Meditated"

**Next Day:**
- Complication automatically resets to "not done" at midnight
- Updates without opening the app

## Architecture Notes

### Data Flow

```
TimerRunningView.logSession()
  ↓
WatchViewModel.logMeditationSession()
  ↓
MeditationStorage.recordMeditation()
  ↓
UserDefaults.standard.set(Date(), forKey: "lastMeditationDate")
  ↓
WidgetCenter.shared.reloadAllTimelines()
  ↓
MeditationStatusWidget updates on watch face
```

### Timeline Updates

The widget uses a smart update policy:
- **Immediate**: When meditation is logged (via `WidgetCenter.shared.reloadAllTimelines()`)
- **Scheduled**: Automatically at midnight to reset for the new day
- **On Launch**: When the watch face is displayed after being hidden

### Storage

- Uses `UserDefaults.standard` (no App Group needed since Widget and Watch app share the same container on watchOS)
- Key: `"lastMeditationDate"`
- Value: `Date` object of last meditation session
- Reset: Never (automatically considered "not today" after midnight)

## Troubleshooting

### Complication Not Appearing

1. Ensure the Widget target is properly embedded in the Watch app
2. Check that Info.plist has the complication families listed
3. Clean build folder (**Product > Clean Build Folder**)
4. Restart Simulator or uninstall/reinstall on device

### Complication Not Updating

1. Check console logs for "✅ Recorded meditation date and updated complication"
2. Verify `WidgetCenter.shared.reloadAllTimelines()` is being called
3. Try force-touching the watch face to refresh
4. Check Settings > General > Background App Refresh is enabled

### Widget Shows Placeholder

This is normal when first adding the complication. It will show real data after:
- First meditation session is logged
- Watch face is refreshed
- App is opened at least once

## Code Review Checklist

Since complications have limited simulator testing, verify the implementation via code review:

- [x] **MeditationStorage** properly saves/loads dates from UserDefaults
- [x] **didMeditateToday()** correctly uses `Calendar.current.isDateInToday()`
- [x] **WatchViewModel** calls `recordMeditation()` when sessions complete
- [x] **WidgetCenter** reload is called after logging session
- [x] **Timeline policy** schedules update at midnight via `.after(tomorrow)`
- [x] **All complication families** supported (circular, rectangular, inline, corner)
- [x] **Visual states** clearly distinguish done (green/checkmark) vs not done (gray/circle)
- [x] **Widget taps** open the main app (automatic with WidgetKit)

## Future Enhancements

Potential improvements for future iterations:

1. **Streak Display**: Show current meditation streak in rectangular complication
2. **Weekly Progress**: Display weekly compliance percentage
3. **Time Until Midnight**: Countdown for today's meditation goal
4. **App Group**: If iOS companion app needs to access meditation status
5. **Lock Screen Widget**: iOS 16+ lock screen widgets for meditation status
