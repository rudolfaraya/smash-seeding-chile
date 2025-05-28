class CreateTeams < ActiveRecord::Migration[7.2]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :acronym, null: false
      t.text :logo
      t.text :description

      t.timestamps
    end

    add_index :teams, :name, unique: true
    add_index :teams, :acronym, unique: true
  end
end
