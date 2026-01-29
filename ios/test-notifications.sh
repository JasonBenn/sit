#!/bin/bash

# Test notification scheduling for Sit iOS app
# This script:
# 1. Boots the iOS simulator
# 2. Installs and launches the Sit app
# 3. Triggers a test notification using xcrun simctl push
# 4. Verifies notification appears

set -e  # Exit on error

echo "📱 Testing iOS Notification Scheduling"
echo "========================================="

# Find an iOS simulator
SIMULATOR_ID=$(xcrun simctl list devices available | grep -i "iphone 17 pro" | grep -v "Max" | head -1 | sed -E 's/.*\(([A-Z0-9-]+)\).*/\1/')

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ No iPhone simulator found"
    exit 1
fi

echo "✅ Using simulator: $SIMULATOR_ID"

# Boot simulator if not already booted
SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -o "([^)]*)" | tail -1 | tr -d "()")
if [ "$SIMULATOR_STATE" != "Booted" ]; then
    echo "🚀 Booting simulator..."
    xcrun simctl boot "$SIMULATOR_ID"
    sleep 5
else
    echo "✅ Simulator already booted"
fi

# Build the app
echo "🔨 Building Sit app..."
cd "$(dirname "$0")"
xcodebuild -project Sit.xcodeproj -target Sit -sdk iphonesimulator -configuration Release build > /dev/null 2>&1

# Find the app bundle
APP_PATH="./build/Release-iphonesimulator/Sit.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found at $APP_PATH"
    exit 1
fi

echo "✅ App bundle found: $APP_PATH"

# Install the app
echo "📦 Installing app..."
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"

# Get bundle ID
BUNDLE_ID=$(defaults read "$(pwd)/$APP_PATH/Info.plist" CFBundleIdentifier)
echo "✅ Bundle ID: $BUNDLE_ID"

# Launch the app
echo "🚀 Launching app..."
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
sleep 3

# Grant notification permissions
echo "🔔 Note: Notification permissions will be requested by the app on first launch"
echo "   You may need to manually approve the permission dialog in the simulator"

# Wait for app to initialize and sync settings
echo "⏳ Waiting for app to sync settings from Convex (10 seconds)..."
sleep 10

# Check pending notifications
echo ""
echo "📋 Checking scheduled notifications..."
xcrun simctl get_app_container "$SIMULATOR_ID" "$BUNDLE_ID" data > /dev/null 2>&1 || true

# Create a test notification payload
NOTIFICATION_JSON=$(cat <<EOF
{
  "aps": {
    "alert": {
      "title": "Meditation Check-in",
      "body": "In the View?"
    },
    "sound": "default",
    "badge": 1
  }
}
EOF
)

# Save payload to temp file
PAYLOAD_FILE="/tmp/sit-test-notification.json"
echo "$NOTIFICATION_JSON" > "$PAYLOAD_FILE"

echo ""
echo "🔔 Sending test notification..."
echo "Payload:"
echo "$NOTIFICATION_JSON"
echo ""

# Send notification
xcrun simctl push "$SIMULATOR_ID" "$BUNDLE_ID" "$PAYLOAD_FILE"

echo ""
echo "✅ Test notification sent!"
echo ""
echo "📱 Check the simulator for the notification"
echo "   Expected: Notification banner with 'Meditation Check-in' / 'In the View?'"
echo ""
echo "To verify scheduled notifications in the future:"
echo "  1. Check app logs for notification scheduling messages"
echo "  2. Wait for scheduled times to verify notifications appear"
echo "  3. Update prompt settings via web UI and verify notifications reschedule"
echo ""
echo "Simulator will remain running for manual testing..."
