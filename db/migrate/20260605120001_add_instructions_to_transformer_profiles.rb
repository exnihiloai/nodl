class AddInstructionsToTransformerProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :transformer_profiles, :instructions, :text
  end
end
