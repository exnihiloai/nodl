namespace :licenses do
  desc "Regenerate config/third_party_licenses.yml from the live dependency tree"
  task generate: :environment do
    target = ThirdPartyLicenses::CONFIG
    inventory = ThirdPartyLicenseInventory.build

    header = <<~HDR
      # Third-party software distributed with Nodl, grouped by license family.
      #
      # GENERATED FILE — do not edit by hand. Regenerate with:
      #   bin/rails licenses:generate
      #
      # Gems are derived from the locked dependency tree (Bundler `default`
      # group), so versions track Gemfile.lock. Non-gem assets are merged from
      # config/third_party_assets.yml. Development- and test-only tooling is not
      # redistributed and is therefore not listed here; the full inventory lives
      # in doc/design-output/third-party-software.md.
      #
      # Each group references a canonical license text in
      # config/third_party_licenses/<body_file>. Per-component copyright notices
      # are reproduced alongside each entry.
      #
      # The drift guard (test/lib/third_party_license_inventory_test.rb) fails
      # `make check` whenever this file no longer matches the installed bundle.
    HDR

    body = inventory.to_yaml.sub(/\A---\n/, "")
    File.write(target, "#{header}\n#{body}")

    total = inventory.fetch("groups").sum { |g| g.fetch("components").size }
    puts "Wrote #{target.relative_path_from(Rails.root)} " \
      "(#{inventory.fetch("groups").size} groups, #{total} components)."
    puts "Review the diff (git diff -- #{target.relative_path_from(Rails.root)}) and commit."
  end
end
