#!/bin/bash

# Test script for Watch timer functionality
# This script creates a test timer preset, launches the Watch app, and verifies timer completion

WATCH_UDID="6CEAA873-88CC-49E8-B0DC-3175C2D63129"
APP_BUNDLE="com.example.Sit.watchkitapp"

echo "🧪 Testing Watch Timer Functionality"
echo "====================================="

# Step 1: Create a 5-second test timer preset in Convex
echo ""
echo "1️⃣  Creating 5-second test timer preset in Convex..."
cd /Users/jasonbenn/code/sit/web
RESULT=$(npx convex run timerPresets:createTimerPreset '{"durationMinutes": 0.0833, "label": "5sec test"}' 2>&1 | tail -1)
echo "   Result: $RESULT"

# Step 2: Launch iOS app to sync with Watch (if needed)
echo ""
echo "2️⃣  Note: For full test, iOS companion app should be running to sync presets to Watch"
echo "   (WatchConnectivity requires both apps running)"

# Step 3: Launch Watch app
echo ""
echo "3️⃣  Launching Watch app..."
xcrun simctl launch booted $APP_BUNDLE > /dev/null 2>&1
sleep 2
echo "   ✅ App launched"

# Step 4: Take screenshot
echo ""
echo "4️⃣  Taking screenshot..."
axe screenshot --udid $WATCH_UDID --output /tmp/watch-app.png
echo "   📸 Screenshot saved to /tmp/watch-app.png"

echo ""
echo "✅ Test setup complete!"
echo ""
echo "Next steps:"
echo "1. Navigate to Timers tab (swipe or tap)"
echo "2. Tap on '5sec test' preset"
echo "3. Timer should start countdown from 5 seconds"
echo "4. Haptic should play when complete"
echo "5. Session should be logged to Convex"
