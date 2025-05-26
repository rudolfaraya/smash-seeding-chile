class AddSmashCharactersToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :character_1, :string, null: true
    add_column :players, :skin_1, :integer, null: true, default: 1
    add_column :players, :character_2, :string, null: true
    add_column :players, :skin_2, :integer, null: true, default: 1
    add_column :players, :character_3, :string, null: true
    add_column :players, :skin_3, :integer, null: true, default: 1

    # Agregar índices para búsquedas eficientes
    add_index :players, :character_1
    add_index :players, :character_2
    add_index :players, :character_3
  end
end
