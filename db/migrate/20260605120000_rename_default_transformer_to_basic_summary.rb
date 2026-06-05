class RenameDefaultTransformerToBasicSummary < ActiveRecord::Migration[8.1]
  def up
    TransformerProfile.where(handle: "default", name: "Default Transformer").update_all(name: "Basic Summary")
  end

  def down
    TransformerProfile.where(handle: "default", name: "Basic Summary").update_all(name: "Default Transformer")
  end
end
