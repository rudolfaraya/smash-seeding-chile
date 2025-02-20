class CreatePlayers < ActiveRecord::Migration[7.2]
  def change
    create_table :players do |t|
      t.string :entrant_name
      t.integer :user_id
      t.string :name
      t.string :discriminator
      t.text :bio
      t.string :city
      t.string :state
      t.string :country
      t.string :gender_pronoum
      t.string :birthday
      t.string :twitter_handle

      t.timestamps
    end
  end
end
