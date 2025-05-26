class AddPerformanceIndexesToPlayers < ActiveRecord::Migration[7.2]
  def change
    # Índices para mejorar el rendimiento de búsquedas
    add_index :players, [ :name, :entrant_name ], name: 'index_players_on_names'
    add_index :players, :twitter_handle

    # Índices para event_seeds para mejorar joins
    add_index :event_seeds, [ :player_id, :event_id ], name: 'index_event_seeds_on_player_and_event'

    # Índices para tournaments para mejorar ordenamiento por fecha
    add_index :tournaments, :start_at

    # Índice compuesto para la consulta optimizada
    add_index :events, [ :tournament_id, :id ], name: 'index_events_on_tournament_and_id'
  end
end
