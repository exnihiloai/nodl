require "test_helper"

# Quality gate: keeps config/third_party_licenses.yml (the data behind the
# public /licenses page) in lockstep with the installed dependency tree.
# When it fails it prints imperative, copy-pasteable fix instructions.
class ThirdPartyLicenseInventoryTest < ActiveSupport::TestCase
  test "committed inventory matches the installed dependency tree" do
    generated = build_inventory
    committed = YAML.load_file(ThirdPartyLicenses::CONFIG)

    flunk(drift_message(generated, committed)) unless generated == committed

    assert_equal committed, generated
  end

  test "every group references an existing license text and every component has a notice" do
    YAML.load_file(ThirdPartyLicenses::CONFIG).fetch("groups").each do |group|
      body = ThirdPartyLicenseInventory::TEXTS_DIR.join(group.fetch("body_file"))
      assert body.exist?, missing_text_message(group, body)

      group.fetch("components").each do |component|
        assert component["copyright"].present?,
          "#{component["name"]} (#{group["id"]}) has no copyright notice. " \
          "Add one to config/third_party_assets.yml (assets) or to the " \
          "OVERRIDES map in lib/third_party_license_inventory.rb (gems), " \
          "then run: bin/rails licenses:generate"
      end
    end
  end

  private

  def build_inventory
    ThirdPartyLicenseInventory.build
  rescue ThirdPartyLicenseInventory::UnmappedLicenseError => e
    flunk(unmapped_license_message(e))
  end

  def drift_message(generated, committed)
    <<~MSG
      Third-party license inventory is out of date.

      config/third_party_licenses.yml no longer matches the installed bundle —
      a dependency was probably added, removed, or upgraded. This file backs the
      public /licenses page, so it must stay accurate.

      Detected differences (committed -> current bundle):
      #{indent(diff_lines(committed, generated))}

      To clear this gate:

        1. Regenerate the inventory from the current bundle:
             bin/rails licenses:generate

        2. Review the diff. For any NEWLY ADDED component, sanity-check the
           auto-inferred copyright notice and license family — the generator
           guesses these from each gem's license file:
             git diff -- config/third_party_licenses.yml

        3. Commit config/third_party_licenses.yml.

        4. Re-run the gate until green:
             make check
    MSG
  end

  def unmapped_license_message(error)
    <<~MSG
      Cannot build the third-party license inventory: an unmapped license.

      #{error.message}

      To clear this gate:

        1. Decide which license family this belongs to and map its raw license
           string in lib/third_party_license_inventory.rb (FAMILIES).

        2. If it is a new family, also:
             - add it to GROUP_META (display name + body file), and
             - add the canonical license text at
               config/third_party_licenses/<body_file>.

        3. Regenerate and re-run the gate:
             bin/rails licenses:generate
             make check
    MSG
  end

  def missing_text_message(group, body)
    <<~MSG
      Missing license text for group "#{group["id"]}".

      Expected a canonical license file at:
        #{body.relative_path_from(Rails.root)}

      Create it with the full text of the #{group["name"]}, then run:
        make check
    MSG
  end

  # Flattens both inventories to "<group>/<name>" => version and reports
  # added / removed / version-changed components.
  def diff_lines(committed, generated)
    before = flatten(committed)
    after = generated.is_a?(Hash) ? flatten(generated) : {}

    added = (after.keys - before.keys).sort.map { |k| "  + added:   #{k} #{after[k]}" }
    removed = (before.keys - after.keys).sort.map { |k| "  - removed: #{k} #{before[k]}" }
    changed = (before.keys & after.keys).select { |k| before[k] != after[k] }.sort
      .map { |k| "  ~ changed: #{k} #{before[k]} -> #{after[k]}" }

    lines = added + removed + changed
    lines.empty? ? [ "  (component lists match; group metadata or ordering differs)" ] : lines
  end

  def flatten(inventory)
    inventory.fetch("groups").each_with_object({}) do |group, acc|
      group.fetch("components").each do |component|
        acc["#{group["id"]}/#{component["name"]}"] = component["version"]
      end
    end
  end

  def indent(lines)
    Array(lines).join("\n")
  end
end
