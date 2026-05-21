#!/usr/bin/env ruby
# Adds KeepKeyTests group and source files to secantTests target.
require 'xcodeproj'

PROJ_PATH = File.expand_path('../secant.xcodeproj', __dir__)
proj = Xcodeproj::Project.open(PROJ_PATH)

# ---- locate the secantTests group and target ----
tests_group = proj.groups.find { |g| g.path == 'secantTests' }
abort "ERROR: could not find secantTests group" unless tests_group

tests_target = proj.targets.find { |t| t.name == 'secantTests' }
abort "ERROR: could not find secantTests target" unless tests_target

# ---- get or create the KeepKeyTests group ----
keepkey_group = tests_group.groups.find { |g| g.name == 'KeepKeyTests' }
if keepkey_group.nil?
  keepkey_group = tests_group.new_group('KeepKeyTests', 'KeepKeyTests')
  puts "Created KeepKeyTests group."
else
  puts "KeepKeyTests group already exists — checking for missing files."
end

# ---- files to include ----
files = [
  'ConnectKeepKeyTests.swift',
  'AddKeepKeyHWWalletTests.swift',
  'SignWithKeepKeyCoordFlowTests.swift',
]

existing_names = keepkey_group.files.map(&:path)
source_phase = tests_target.source_build_phase

files.each do |filename|
  if existing_names.include?(filename)
    puts "Already present: #{filename}"
    next
  end
  ref = keepkey_group.new_file(filename)
  ref.last_known_file_type = 'sourcecode.swift'
  source_phase.add_file_reference(ref)
  puts "Added: #{filename}"
end

proj.save
puts "Project saved."
