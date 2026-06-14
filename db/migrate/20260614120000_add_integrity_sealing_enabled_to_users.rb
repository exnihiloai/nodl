class AddIntegritySealingEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :integrity_sealing_enabled, :boolean, default: false, null: false
  end
end
