class AddGoogleOauthFieldsToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :name, :string
    add_column :users, :avatar_url, :string

    add_index :users, %i[provider uid], unique: true, algorithm: :concurrently
  end
end
