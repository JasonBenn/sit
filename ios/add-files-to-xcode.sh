#!/bin/bash

# Script to add TimerViewModel.swift and TimerRunningView.swift to SitWatch target

PROJ_FILE="Sit.xcodeproj/project.pbxproj"

# Generate random UUIDs for the new files (24 hex chars each)
UUID1_BUILD=$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]')
UUID1_FILE=$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]')
UUID2_BUILD=$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]')
UUID2_FILE=$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]')

echo "Adding TimerViewModel.swift and TimerRunningView.swift to Xcode project..."
echo "UUID1_BUILD: $UUID1_BUILD"
echo "UUID1_FILE: $UUID1_FILE"
echo "UUID2_BUILD: $UUID2_BUILD"
echo "UUID2_FILE: $UUID2_FILE"

# Backup the project file
cp "$PROJ_FILE" "$PROJ_FILE.backup"

# Use Perl for multi-line replacements
# 1. Add PBXBuildFile entries (after FB161477995B0F1398D7FD32)
perl -i -pe "s/(FB161477995B0F1398D7FD32.*Sources.*)/\$1\n\t\t$UUID1_BUILD \/* TimerViewModel.swift in Sources *\/ = {isa = PBXBuildFile; fileRef = $UUID1_FILE \/* TimerViewModel.swift *\/; };\n\t\t$UUID2_BUILD \/* TimerRunningView.swift in Sources *\/ = {isa = PBXBuildFile; fileRef = $UUID2_FILE \/* TimerRunningView.swift *\/; };/" "$PROJ_FILE"

# 2. Add PBXFileReference entries (after FE49D6C2A9E21AB6177EEE74)
perl -i -pe "s/(FE49D6C2A9E21AB6177EEE74.*WatchConnectivity.framework.*)/\$1\n\t\t$UUID1_FILE \/* TimerViewModel.swift *\/ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = TimerViewModel.swift; sourceTree = \"<group>\"; };\n\t\t$UUID2_FILE \/* TimerRunningView.swift *\/ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = TimerRunningView.swift; sourceTree = \"<group>\"; };/" "$PROJ_FILE"

# 3. Add to SitWatch group (after Models.swift)
perl -i -pe "s/(462DA20C9F59D021D7075243.*Models.swift.*,)/\$1\n\t\t\t\t$UUID1_FILE \/* TimerViewModel.swift *\/,\n\t\t\t\t$UUID2_FILE \/* TimerRunningView.swift *\/,/" "$PROJ_FILE"

# 4. Add to Sources build phase (after E6F82F972C02F123D44EBEDC)
perl -i -pe "s/(E6F82F972C02F123D44EBEDC.*Models.swift in Sources.*,)/\$1\n\t\t\t\t$UUID1_BUILD \/* TimerViewModel.swift in Sources *\/,\n\t\t\t\t$UUID2_BUILD \/* TimerRunningView.swift in Sources *\/,/" "$PROJ_FILE"

echo "✅ Files added to Xcode project"
echo "Backup saved to: $PROJ_FILE.backup"
