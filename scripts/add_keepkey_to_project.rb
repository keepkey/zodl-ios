#!/usr/bin/env ruby
# Adds all KeepKey source files, proto-generated files, and SPM packages
# (SwiftProtobuf, WalletConnectSwiftV2) to the secant Xcode project.
#
# Run from the zodl-ios directory:
#   ruby scripts/add_keepkey_to_project.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../secant.xcodeproj', __dir__)
APP_TARGETS = %w[secant-testnet secant-mainnet secant-distrib zashi-internal zashi-testnet].freeze

proj = Xcodeproj::Project.open(PROJECT_PATH)

app_targets = proj.targets.select { |t| APP_TARGETS.include?(t.name) }
puts "Wiring into #{app_targets.map(&:name).join(', ')}"

# ── helpers ────────────────────────────────────────────────────────────────────

def find_group(root, *path_parts)
  path_parts.reduce(root) do |grp, part|
    grp.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.path || c.name) == part }
  end
end

def find_or_create_group(parent, name, path: nil)
  existing = parent.children.find do |c|
    c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.path || c.name) == name
  end
  return existing if existing
  grp = parent.new_group(name, path || name)
  puts "  Created group: #{name}"
  grp
end

def add_file_to_group(proj, group, filename)
  return if group.children.any? { |c| c.respond_to?(:path) && c.path == filename }
  ref = group.new_file(filename)
  ref.last_known_file_type = 'sourcecode.swift'
  ref.source_tree = '<group>'
  puts "  Added file: #{filename}"
  ref
end

def wire_to_targets(targets, file_ref)
  return unless file_ref
  targets.each do |target|
    sources_phase = target.source_build_phase
    next if sources_phase.files_references.include?(file_ref)
    sources_phase.add_file_reference(file_ref)
  end
end

# ── SPM packages ───────────────────────────────────────────────────────────────

def find_or_add_package(proj, name, url, requirement)
  existing = proj.packages.find { |p| p.repositoryURL == url }
  return existing if existing
  pkg = proj.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg.repositoryURL = url
  pkg.requirement = requirement
  proj.root_object.package_references << pkg
  puts "  Added SPM package: #{name}"
  pkg
end

def link_product_to_target(proj, target, package_ref, product_name)
  dep = proj.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = package_ref
  dep.product_name = product_name
  target.package_product_dependencies << dep

  build_file = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  target.frameworks_build_phase.files << build_file
  puts "    Linked #{product_name} → #{target.name}"
end

# ── 1. Dependencies/KeepKey ────────────────────────────────────────────────────
puts "\n[1] Dependencies/KeepKey"
sources_group = find_group(proj.main_group, 'secant', 'Sources')
raise 'Could not find secant/Sources group' unless sources_group

deps_group = find_group(sources_group, 'Dependencies')
raise 'Could not find Dependencies group' unless deps_group

kk_dep_group = find_or_create_group(deps_group, 'KeepKey')
%w[KeepKeyTransportInterface.swift KeepKeyTransportLiveKey.swift].each do |f|
  ref = add_file_to_group(proj, kk_dep_group, f)
  wire_to_targets(app_targets, ref)
end

# ── 2. Features/AddKeepKeyHWWallet ────────────────────────────────────────────
puts "\n[2] Features/AddKeepKeyHWWallet"
features_group = find_group(sources_group, 'Features')
raise 'Could not find Features group' unless features_group

add_kk_group = find_or_create_group(features_group, 'AddKeepKeyHWWallet')
%w[
  AddKeepKeyHWWalletStore.swift
  AddKeepKeyHWWalletView.swift
  KeepKeyConnectedView.swift
  KeepKeyDeviceReadyView.swift
].each do |f|
  ref = add_file_to_group(proj, add_kk_group, f)
  wire_to_targets(app_targets, ref)
end

# ── 3. Features/ConnectKeepKey ────────────────────────────────────────────────
puts "\n[3] Features/ConnectKeepKey"
connect_kk_group = find_or_create_group(features_group, 'ConnectKeepKey')
%w[ConnectKeepKeyStore.swift ConnectKeepKeyView.swift].each do |f|
  ref = add_file_to_group(proj, connect_kk_group, f)
  wire_to_targets(app_targets, ref)
end

# ── 4. CoordFlows (group already exists) ──────────────────────────────────────
puts "\n[4] CoordFlows KeepKey files"
coord_group = find_group(features_group, 'CoordFlows')
raise 'Could not find CoordFlows group' unless coord_group

%w[
  AddKeepKeyHWWalletCoordFlowCoordinator.swift
  AddKeepKeyHWWalletCoordFlowStore.swift
  AddKeepKeyHWWalletCoordFlowView.swift
  SignWithKeepKeyCoordFlowCoordinator.swift
  SignWithKeepKeyCoordFlowStore.swift
  SignWithKeepKeyCoordFlowView.swift
].each do |f|
  ref = add_file_to_group(proj, coord_group, f)
  wire_to_targets(app_targets, ref)
end

# ── 5. SendConfirmation (group already exists) ────────────────────────────────
puts "\n[5] SendConfirmation files"
send_group = find_group(features_group, 'SendConfirmation')
raise 'Could not find SendConfirmation group' unless send_group

%w[SignWithKeepKeyView.swift SigningInProgressView.swift].each do |f|
  ref = add_file_to_group(proj, send_group, f)
  wire_to_targets(app_targets, ref)
end

# ── 6. Generated/Proto (new subgroup) ─────────────────────────────────────────
puts "\n[6] Generated/Proto"
generated_group = find_group(sources_group, 'Generated')
raise 'Could not find Generated group' unless generated_group

proto_group = find_or_create_group(generated_group, 'Proto')
%w[messages-zcash.pb.swift messages.pb.swift types.pb.swift].each do |f|
  ref = add_file_to_group(proj, proto_group, f)
  wire_to_targets(app_targets, ref)
end

# NOTE: SPM packages (SwiftProtobuf, WalletConnectSwiftV2) are added via Xcode UI.
# See scripts/add_spm_packages.md for the exact URLs and versions to use.

# ── Save ───────────────────────────────────────────────────────────────────────
proj.save
puts "\nDone. Project saved to #{PROJECT_PATH}"
