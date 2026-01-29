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

puts "🔧 Fixing file reference paths..."

# Get the SitWatch group
watch_group = project.main_group['SitWatch']

unless watch_group
  puts "❌ SitWatch group not found"
  exit 1
end

# Set the group's path to point to the SitWatch directory
watch_group.path = 'SitWatch'
watch_group.source_tree = '<group>'

puts "  ✓ Set SitWatch group path to 'SitWatch'"

# Update each file reference to use relative paths
watch_group.files.each do |file_ref|
  # File ref paths should be relative to the group
  file_ref.source_tree = '<group>'
  puts "  ✓ Updated #{file_ref.path} source tree"
end

# Save project
project.save

puts "✅ File paths fixed!"
