# Loads the inventory of third-party software distributed with the application
# (config/third_party_licenses.yml) and the canonical license texts it refers
# to (config/third_party_licenses/*.txt). Backs the public /licenses page that
# satisfies attribution/notice obligations of the bundled dependencies.
class ThirdPartyLicenses
  CONFIG = Rails.root.join("config", "third_party_licenses.yml")
  TEXTS_DIR = Rails.root.join("config", "third_party_licenses")

  Component = Data.define(:name, :version, :copyright, :url)
  Group = Data.define(:id, :name, :body, :components)

  class << self
    def groups
      # The inventory only changes on deploy, so cache it outside development
      # where code/config reloading is expected to surface edits immediately.
      return load_groups if Rails.env.development?

      @groups ||= load_groups
    end

    private

    def load_groups
      data = YAML.safe_load_file(CONFIG)
      data.fetch("groups").map do |group|
        Group.new(
          id: group.fetch("id"),
          name: group.fetch("name"),
          body: TEXTS_DIR.join(group.fetch("body_file")).read,
          components: build_components(group.fetch("components"))
        )
      end
    end

    def build_components(rows)
      rows.map do |row|
        Component.new(
          name: row.fetch("name"),
          version: row["version"],
          copyright: row["copyright"],
          url: row["url"]
        )
      end
    end
  end
end
