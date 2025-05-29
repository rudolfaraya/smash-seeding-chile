class AddOptimizedIndexesForPlayersFilter < ActiveRecord::Migration[7.2]
  def change
    # Índice compuesto para filtros por país (optimize country filter)
    add_index :players, :country, name: 'index_players_on_country'
    
    # Índice compuesto para búsqueda de texto optimizada (nombre, entrant_name, twitter)
    add_index :players, "LOWER(entrant_name)", name: 'index_players_on_entrant_name_lower'
    add_index :players, "LOWER(name)", name: 'index_players_on_name_lower'
    add_index :players, "LOWER(twitter_handle)", name: 'index_players_on_twitter_handle_lower'
    
    # Índice para player_teams optimizado para filtros "sin equipo"
    add_index :player_teams, [:team_id, :player_id], name: 'index_player_teams_on_team_player'
    
    # Índice compuesto para optimizar consultas de ordenamiento por fecha
    add_index :tournaments, [:start_at, :id], name: 'index_tournaments_on_start_at_and_id'
    
    # Índice compuesto para eventos con tournaments
    add_index :events, [:tournament_id, :videogame_id], name: 'index_events_on_tournament_videogame'
    
    # Índice para optimizar consultas con event_seeds join
    add_index :event_seeds, [:player_id, :event_id, :seed_num], name: 'index_event_seeds_player_event_seed'
  end
end 