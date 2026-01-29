#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Sit.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Watch target
watch_target = project.targets.find { |t| t.name == 'SitWatch' }

unless watch_target
  puts "❌ Watch target 'SitWatch' not found"
  exit 1
end

# Remove duplicate files from build phases
puts "🔧 Cleaning up duplicate build phase files..."

# Clear all build phases and rebuild them
watch_target.source_build_phase.files.clear
watch_target.resources_build_phase.files.clear

# Get the SitWatch group
watch_group = project.main_group['SitWatch']

unless watch_group
  puts "❌ SitWatch group not found"
  exit 1
end

# Add Swift files to source build phase
watch_group.files.each do |file_ref|
  if file_ref.path.end_with?('.swift')
    # Check if already in build phase
    unless watch_target.source_build_phase.files_references.include?(file_ref)
      watch_target.source_build_phase.add_file_reference(file_ref)
      puts "  ✓ Added #{file_ref.path} to source build phase"
    end
  end
end

# Update build settings to remove CopyAndPreserveArchs issues
watch_target.build_configurations.each do |config|
  config.build_settings.delete('COPY_PHASE_STRIP')
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.Sit.watchkitapp'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'SitWatch/Info.plist'
  config.build_settings['SKIP_INSTALL'] = 'NO'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  puts "  ✓ Updated #{config.name} build settings"
end

# Save project
project.save

puts "✅ Watch target fixed successfully!"
puts ""
puts "Try building again with:"
puts "xcodebuild -project Sit.xcodeproj -scheme SitWatch -sdk watchsimulator -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build"
