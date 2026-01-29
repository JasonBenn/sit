#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Sit.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Remove old Watch target if it exists
old_watch_target = project.targets.find { |t| t.name == 'SitWatch' }
if old_watch_target
  puts "🗑️  Removing old Watch target..."
  project.targets.delete(old_watch_target)
end

# Create new Watch App target with correct type
puts "✨ Creating new Watch App target..."
watch_target = project.new_target(:application, 'SitWatch', :watchos, '10.0')

# Set build settings
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.Sit.watchkitapp'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4' # watchOS
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['INFOPLIST_FILE'] = 'SitWatch/Info.plist'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'NO'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  puts "  ✓ Configured #{config.name} settings"
end

# Add WatchConnectivity framework
watch_target.add_system_framework('WatchConnectivity')
puts "  ✓ Added WatchConnectivity framework"

# Get or create SitWatch group
watch_group = project.main_group.find_subpath('SitWatch', false) || project.main_group.new_group('SitWatch', 'SitWatch')

# Clear existing files in group
watch_group.clear

# Add Watch App files
watch_files = {
  'SitWatchApp.swift' => 'sourcecode.swift',
  'ContentView.swift' => 'sourcecode.swift',
  'WatchViewModel.swift' => 'sourcecode.swift',
  'Models.swift' => 'sourcecode.swift'
}

watch_files.each do |filename, file_type|
  file_ref = watch_group.new_reference(filename)
  file_ref.last_known_file_type = file_type
  watch_target.source_build_phase.add_file_reference(file_ref)
  puts "  ✓ Added #{filename}"
end

# Add Info.plist as resource (not to source build phase)
info_plist_ref = watch_group.new_reference('Info.plist')
info_plist_ref.last_known_file_type = 'text.plist.xml'

# Add WatchConnectivity to iOS target
ios_target = project.targets.find { |t| t.name == 'Sit' }
if ios_target
  ios_target.add_system_framework('WatchConnectivity')
  puts "  ✓ Added WatchConnectivity to iOS target"
  
  # Add WatchConnectivityService.swift to iOS if not already there
  ios_group = project.main_group.find_subpath('Sit', false)
  if ios_group
    watch_service_ref = ios_group.files.find { |f| f.path == 'WatchConnectivityService.swift' }
    unless watch_service_ref
      watch_service_ref = ios_group.new_reference('WatchConnectivityService.swift')
      watch_service_ref.last_known_file_type = 'sourcecode.swift'
      ios_target.source_build_phase.add_file_reference(watch_service_ref)
      puts "  ✓ Added WatchConnectivityService.swift to iOS"
    end
  end
end

# Save project
project.save

puts "✅ Watch target recreated successfully!"
puts ""
puts "Try building with:"
puts "xcodebuild -project Sit.xcodeproj -scheme SitWatch -sdk watchsimulator build CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO"
