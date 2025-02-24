class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events do |t|
      t.belongs_to :tournament, null: false, foreign_key: true
      t.string :name
      t.string :slug

      t.timestamps
    end
  end
end
