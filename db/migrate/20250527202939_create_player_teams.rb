class CreatePlayerTeams < ActiveRecord::Migration[7.2]
  def change
    create_table :player_teams do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.boolean :is_primary, default: false

      t.timestamps
    end

    # Índice único para garantizar que no haya duplicados player-team
    add_index :player_teams, [:player_id, :team_id], unique: true
    
    # Índice único para garantizar que un jugador solo tenga un equipo principal
    add_index :player_teams, :player_id, unique: true, where: "is_primary = true", 
              name: "index_player_teams_on_player_id_primary_unique"
  end
end
