#!/usr/bin/env ruby
# Adds KeepKeyTests group/files and KeepKeySnapshotTests group/file to secantTests target.
require 'xcodeproj'

PROJ_PATH = File.expand_path('../secant.xcodeproj', __dir__)
proj = Xcodeproj::Project.open(PROJ_PATH)

tests_group = proj.groups.find { |g| g.path == 'secantTests' }
abort "ERROR: could not find secantTests group" unless tests_group

tests_target = proj.targets.find { |t| t.name == 'secantTests' }
abort "ERROR: could not find secantTests target" unless tests_target

source_phase = tests_target.source_build_phase

# ---- KeepKeyTests group ----
keepkey_group = tests_group.groups.find { |g| g.name == 'KeepKeyTests' }
if keepkey_group.nil?
  keepkey_group = tests_group.new_group('KeepKeyTests', 'KeepKeyTests')
  puts "Created KeepKeyTests group."
end

unit_files = %w[
  ConnectKeepKeyTests.swift
  AddKeepKeyHWWalletTests.swift
  SignWithKeepKeyCoordFlowTests.swift
]

existing_names = keepkey_group.files.map(&:path)
unit_files.each do |filename|
  if existing_names.include?(filename)
    puts "Already present: #{filename}"
    next
  end
  ref = keepkey_group.new_file(filename)
  ref.last_known_file_type = 'sourcecode.swift'
  source_phase.add_file_reference(ref)
  puts "Added: #{filename}"
end

# ---- KeepKeySnapshotTests group (inside SnapshotTests) ----
snapshot_group = tests_group.groups.find { |g| (g.name || g.path) == 'SnapshotTests' }
abort "ERROR: could not find SnapshotTests group" unless snapshot_group

kk_snapshot_group = snapshot_group.groups.find { |g| g.name == 'KeepKeySnapshotTests' }
if kk_snapshot_group.nil?
  kk_snapshot_group = snapshot_group.new_group('KeepKeySnapshotTests', 'KeepKeySnapshotTests')
  puts "Created KeepKeySnapshotTests group."
end

snapshot_file = 'KeepKeySnapshotTests.swift'
existing_snap = kk_snapshot_group.files.map(&:path)
unless existing_snap.include?(snapshot_file)
  ref = kk_snapshot_group.new_file(snapshot_file)
  ref.last_known_file_type = 'sourcecode.swift'
  source_phase.add_file_reference(ref)
  puts "Added: #{snapshot_file}"
else
  puts "Already present: #{snapshot_file}"
end

proj.save
puts "Project saved."
