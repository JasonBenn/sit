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

puts "🔧 Removing problematic build phases..."

# List all build phases
watch_target.build_phases.each do |phase|
  puts "  Found phase: #{phase.class.name}"
  
  # Remove any Copy Files build phases that might be causing issues
  if phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    puts "  ⚠️  Removing Copy Files phase: #{phase.name}"
    watch_target.build_phases.delete(phase)
  end
end

# Ensure we only have the essential build phases
essential_phases = []
watch_target.build_phases.each do |phase|
  case phase
  when Xcodeproj::Project::Object::PBXSourcesBuildPhase,
       Xcodeproj::Project::Object::PBXFrameworksBuildPhase,
       Xcodeproj::Project::Object::PBXResourcesBuildPhase
    essential_phases << phase
    puts "  ✓ Keeping: #{phase.class.name}"
  else
    puts "  ⚠️  Other phase: #{phase.class.name}"
  end
end

# Update build settings to fix the issue
watch_target.build_configurations.each do |config|
  # Disable VALID_ARCHS copying
  config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
  config.build_settings.delete('VALID_ARCHS')
  puts "  ✓ Updated #{config.name} build settings"
end

# Save project
project.save

puts "✅ Build phases cleaned up!"
