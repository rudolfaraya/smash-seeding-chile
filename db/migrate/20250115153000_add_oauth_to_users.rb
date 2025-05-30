class AddOauthToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :startgg_id, :integer
    add_column :users, :startgg_username, :string
    add_column :users, :role, :integer, default: 0
    add_reference :users, :player, null: true, foreign_key: true
    
    add_index :users, :startgg_id, unique: true
    add_index :users, :role
  end
end 