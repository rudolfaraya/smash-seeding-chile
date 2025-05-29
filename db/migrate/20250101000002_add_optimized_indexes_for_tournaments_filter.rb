class AddOptimizedIndexesForTournamentsFilter < ActiveRecord::Migration[7.2]
  def change
    # Índice compuesto para filtros por estado y fecha
    add_index :tournaments, [:start_at, :region], name: 'index_tournaments_on_start_at_and_region'
    add_index :tournaments, [:start_at, :city], name: 'index_tournaments_on_start_at_and_city'
    
    # Índice para búsqueda de texto optimizada (nombre)
    add_index :tournaments, "LOWER(name)", name: 'index_tournaments_on_name_lower'
    
    # Índice compuesto para events con smash ultimate específicamente
    add_index :events, [:tournament_id, :videogame_id, :team_max_players], 
              name: 'index_events_on_tournament_videogame_team_max',
              where: 'videogame_id = 1386' # Smash Ultimate ID
    
    # Índice para optimizar conteos de event_seeds por torneo
    add_index :event_seeds, [:event_id, :player_id], name: 'index_event_seeds_on_event_player'
    
    # Índice para el filtrado por attendees_count cuando no hay datos de Smash
    add_index :tournaments, [:attendees_count, :start_at], name: 'index_tournaments_on_attendees_start_at'
    
    # Índice para slug (usado en URLs)
    add_index :tournaments, :slug, name: 'index_tournaments_on_slug'
  end
end 