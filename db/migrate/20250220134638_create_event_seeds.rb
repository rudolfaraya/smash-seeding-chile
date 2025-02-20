class CreateEventSeeds < ActiveRecord::Migration[7.2]
  def change
    create_table :event_seeds do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :event_id, null: false
      t.string :event_name
      t.integer :seed_num, null: false

      t.timestamps
    end
  end
end
