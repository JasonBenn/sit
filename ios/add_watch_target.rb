#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Sit.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target (iOS app)
ios_target = project.targets.find { |t| t.name == 'Sit' }

unless ios_target
  puts "❌ iOS target 'Sit' not found"
  exit 1
end

# Create Watch App target
watch_target = project.new_target(:watch2_app, 'SitWatch', :watchos, '10.0')

# Set basic build settings
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.Sit.watchkitapp'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4' # watchOS
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['INFOPLIST_FILE'] = 'SitWatch/Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
end

# Add WatchConnectivity framework
watch_target.add_system_framework('WatchConnectivity')

# Get or create SitWatch group
watch_group = project.main_group.find_subpath('SitWatch', true)

# Add Watch App files to the target
watch_files = [
  'SitWatch/SitWatchApp.swift',
  'SitWatch/ContentView.swift',
  'SitWatch/WatchViewModel.swift',
  'SitWatch/Models.swift',
  'SitWatch/Info.plist'
]

watch_files.each do |file_path|
  file_ref = watch_group.new_reference(file_path.split('/').last)
  file_ref.last_known_file_type = case file_path
  when /\.swift$/
    'sourcecode.swift'
  when /\.plist$/
    'text.plist.xml'
  end

  # Add to build phases
  if file_path.end_with?('.swift')
    watch_target.source_build_phase.add_file_reference(file_ref)
  elsif file_path.end_with?('.plist')
    watch_target.resources_build_phase.add_file_reference(file_ref)
  end
end

# Add WatchConnectivity to iOS target as well
ios_target.add_system_framework('WatchConnectivity')

# Add WatchConnectivityService.swift to iOS target if not already added
ios_group = project.main_group.find_subpath('Sit', false)
if ios_group
  watch_connectivity_file = ios_group.files.find { |f| f.path == 'WatchConnectivityService.swift' }
  unless watch_connectivity_file
    watch_connectivity_ref = ios_group.new_reference('WatchConnectivityService.swift')
    watch_connectivity_ref.last_known_file_type = 'sourcecode.swift'
    ios_target.source_build_phase.add_file_reference(watch_connectivity_ref)
  end
end

# Save project
project.save

puts "✅ Watch target added successfully!"
puts "📱 iOS target updated with WatchConnectivity"
puts "⌚ Watch target 'SitWatch' created"
puts ""
puts "Next steps:"
puts "1. Open Sit.xcodeproj in Xcode"
puts "2. Select the SitWatch scheme"
puts "3. Build and run on Apple Watch Simulator"
