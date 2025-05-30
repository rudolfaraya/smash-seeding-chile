class CreateUserPlayerRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :user_player_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :status
      t.text :message
      t.text :admin_response
      t.datetime :requested_at
      t.datetime :responded_at

      t.timestamps
    end
  end
end
