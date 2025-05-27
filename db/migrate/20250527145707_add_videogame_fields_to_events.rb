class AddVideogameFieldsToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :videogame_id, :integer
    add_column :events, :videogame_name, :string
    add_column :events, :team_min_players, :integer
    add_column :events, :team_max_players, :integer
    
    # Agregar índices para mejorar el rendimiento de las consultas de filtrado
    add_index :events, :videogame_id
    add_index :events, [:videogame_id, :team_max_players]
  end
end
