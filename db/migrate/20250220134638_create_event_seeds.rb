class CreateEventSeeds < ActiveRecord::Migration[7.2]
  def change
    create_table :event_seeds do |t|
      t.references :event, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :seed_num
      t.string :character_stock_icon

      t.timestamps
    end
  end
end
