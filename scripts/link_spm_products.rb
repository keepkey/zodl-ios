#!/usr/bin/env ruby
# Links SwiftProtobuf, WalletConnectSign, and WalletConnectRelay to all app
# targets. Run this once after adding the packages via Xcode UI.
#
#   ruby scripts/link_spm_products.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../secant.xcodeproj', __dir__)
APP_TARGETS = %w[secant-testnet secant-mainnet secant-distrib zashi-internal zashi-testnet].freeze

PRODUCTS = [
  { url: 'https://github.com/apple/swift-protobuf',             name: 'SwiftProtobuf' },
  { url: 'https://github.com/WalletConnect/WalletConnectSwiftV2', name: 'WalletConnectSign' },
  { url: 'https://github.com/WalletConnect/WalletConnectSwiftV2', name: 'WalletConnectRelay' },
].freeze

proj = Xcodeproj::Project.open(PROJECT_PATH)
app_targets = proj.targets.select { |t| APP_TARGETS.include?(t.name) }
puts "Linking into: #{app_targets.map(&:name).join(', ')}\n\n"

PRODUCTS.each do |product|
  pkg = proj.root_object.package_references.find { |p| p.respond_to?(:repositoryURL) && p.repositoryURL == product[:url] }
  unless pkg
    abort "ERROR: Package not found for URL #{product[:url]}. Add it via Xcode first."
  end

  app_targets.each do |target|
    already_linked = target.package_product_dependencies.any? do |dep|
      dep.product_name == product[:name]
    end

    if already_linked
      puts "  [skip] #{product[:name]} already linked to #{target.name}"
      next
    end

    dep = proj.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dep.package = pkg
    dep.product_name = product[:name]
    target.package_product_dependencies << dep

    build_file = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dep
    target.frameworks_build_phase.files << build_file

    puts "  [added] #{product[:name]} → #{target.name}"
  end
end

proj.save
puts "\nDone. Saved #{PROJECT_PATH}"
