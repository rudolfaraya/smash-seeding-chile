class CreateTournaments < ActiveRecord::Migration[7.2]
  def change
    create_table :tournaments do |t|
      t.string :name
      t.string :slug
      t.datetime :start_at
      t.datetime :end_at
      t.string :venue_address

      t.timestamps
    end
  end
end
