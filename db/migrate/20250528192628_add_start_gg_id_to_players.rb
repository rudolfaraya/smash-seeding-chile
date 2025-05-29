class AddStartGgIdToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :start_gg_id, :integer
    add_index :players, :start_gg_id, unique: true
  end
end
