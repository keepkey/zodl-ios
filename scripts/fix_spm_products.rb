#!/usr/bin/env ruby
# Removes incorrectly-named WalletConnectSign/WalletConnectRelay product deps
# and adds the correct product name "WalletConnect" (which targets WalletConnectSign).
# Also adds SwiftProtobuf if not already linked.
#
#   ruby scripts/fix_spm_products.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../secant.xcodeproj', __dir__)
APP_TARGETS = %w[secant-testnet secant-mainnet secant-distrib zashi-internal zashi-testnet].freeze

# Products to remove (wrong names we added earlier)
REMOVE_PRODUCTS = %w[WalletConnectSign WalletConnectRelay].freeze

# Products to add (correct names)
ADD_PRODUCTS = [
  { url: 'https://github.com/apple/swift-protobuf',               name: 'SwiftProtobuf' },
  { url: 'https://github.com/WalletConnect/WalletConnectSwiftV2', name: 'WalletConnect' },
].freeze

proj = Xcodeproj::Project.open(PROJECT_PATH)
app_targets = proj.targets.select { |t| APP_TARGETS.include?(t.name) }
puts "Fixing targets: #{app_targets.map(&:name).join(', ')}\n\n"

# ── Remove wrong product entries ───────────────────────────────────────────────
puts "[1] Removing incorrectly-named products"
all_product_deps = proj.objects.select { |o| o.isa == 'XCSwiftPackageProductDependency' }
build_files      = proj.objects.select { |o| o.isa == 'PBXBuildFile' }

wrong_deps = all_product_deps.select { |d| REMOVE_PRODUCTS.include?(d.product_name) }
puts "  Found #{wrong_deps.size} wrong deps to remove"

wrong_deps.each do |dep|
  # Remove the PBXBuildFile that references this dep
  matching_bfs = build_files.select { |bf| bf.respond_to?(:product_ref) && bf.product_ref == dep }
  matching_bfs.each do |bf|
    # Remove from every frameworks build phase that contains it
    app_targets.each do |t|
      t.frameworks_build_phase.files.delete(bf)
    end
    bf.remove_from_project
    puts "  Removed build file for #{dep.product_name}"
  end

  # Remove from every target's packageProductDependencies
  app_targets.each do |t|
    t.package_product_dependencies.delete(dep)
  end

  dep.remove_from_project
  puts "  Removed dep: #{dep.product_name}"
end

# ── Add correct products ───────────────────────────────────────────────────────
puts "\n[2] Adding correct products"
ADD_PRODUCTS.each do |product|
  pkg = proj.root_object.package_references.find do |p|
    p.respond_to?(:repositoryURL) && p.repositoryURL == product[:url]
  end
  unless pkg
    abort "ERROR: Package not found for URL #{product[:url]}. Add it via Xcode first."
  end

  app_targets.each do |target|
    already = target.package_product_dependencies.any? { |d| d.product_name == product[:name] }
    if already
      puts "  [skip] #{product[:name]} already in #{target.name}"
      next
    end

    dep = proj.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dep.package = pkg
    dep.product_name = product[:name]
    target.package_product_dependencies << dep

    bf = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
    bf.product_ref = dep
    target.frameworks_build_phase.files << bf

    puts "  [added] #{product[:name]} → #{target.name}"
  end
end

proj.save
puts "\nDone. Saved #{PROJECT_PATH}"
