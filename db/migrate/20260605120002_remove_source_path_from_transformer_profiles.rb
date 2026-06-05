class RemoveSourcePathFromTransformerProfiles < ActiveRecord::Migration[8.1]
  def change
    remove_column :transformer_profiles, :source_path, :string, null: false
  end
end
