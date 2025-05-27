require 'set'

class StatsController < ApplicationController
  def index
    # Métricas generales
    @total_tournaments = Tournament.count
    @total_events = Event.count
    @total_players = Player.count
    @total_seeds = EventSeed.count
    
    # Eventos válidos vs total
    @valid_events = Event.valid_smash_singles.count
    @invalid_events = @total_events - @valid_events
    
    # Distribución por región (ordenada geográficamente)
    tournaments_by_region_raw = Tournament.group(:region)
                                         .count
                                         .transform_keys { |region| region || 'Sin región' }
    
    @tournaments_by_region = {}
    region_order_display = [
      'Arica y Parinacota',
      'Tarapacá', 
      'Antofagasta',
      'Atacama',
      'Coquimbo',
      'Valparaíso',
      'Metropolitana de Santiago',
      'Libertador Gral. Bernardo O\'Higgins',
      'Maule',
      'Ñuble',
      'Biobío',
      'Araucanía',
      'Los Ríos',
      'Los Lagos',
      'Aysén del Gral. Carlos Ibáñez del Campo',
      'Magallanes y de la Antártica Chilena',
      'Online',
      'Sin región'
    ]
    
    region_order_display.each do |region|
      if tournaments_by_region_raw.key?(region)
        @tournaments_by_region[region] = tournaments_by_region_raw[region]
      end
    end
    
    # Torneos online vs presenciales
    @online_tournaments = Tournament.where(region: 'Online').count
    @presential_tournaments = @total_tournaments - @online_tournaments
    
    # Promedio de asistentes
    @avg_attendees_overall = Tournament.where.not(attendees_count: nil)
                                     .average(:attendees_count)&.round(1) || 0
    
    avg_attendees_raw = Tournament.where.not(attendees_count: nil)
                                  .group(:region)
                                  .average(:attendees_count)
                                  .transform_values { |avg| avg&.round(1) || 0 }
    
    # Orden geográfico de las regiones (de norte a sur)
    region_order = [
      'Arica y Parinacota',
      'Tarapacá', 
      'Antofagasta',
      'Atacama',
      'Coquimbo',
      'Valparaíso',
      'Metropolitana de Santiago',
      'Libertador Gral. Bernardo O\'Higgins',
      'Maule',
      'Ñuble',
      'Biobío',
      'Araucanía',
      'Los Ríos',
      'Los Lagos',
      'Aysén del Gral. Carlos Ibáñez del Campo',
      'Magallanes y de la Antártica Chilena',
      'Online',
      nil  # Sin región al final
    ]
    
    @avg_attendees_by_region = {}
    region_order.each do |region|
      if avg_attendees_raw.key?(region)
        @avg_attendees_by_region[region] = avg_attendees_raw[region]
      end
    end
    
    # Distribución temporal (usando start_at - método simplificado)
    tournaments_with_year = Tournament.where.not(start_at: nil)
    year_counts = {}
    
    tournaments_with_year.each do |tournament|
      year = Time.at(tournament.start_at).year
      year_counts[year] = (year_counts[year] || 0) + 1
    end
    
    @tournaments_by_year = year_counts.sort.to_h
    
    @tournaments_by_month = Tournament.where('start_at > ?', 1.year.ago.to_i)
                                    .group("strftime('%Y-%m', datetime(start_at, 'unixepoch'))")
                                    .count
    
    # Top jugadores más activos (consulta simplificada con LIMIT para evitar timeouts)
    begin
      active_players_data = EventSeed.joins(:event, :player)
                                   .select('players.entrant_name, COUNT(DISTINCT events.tournament_id) as tournament_count')
                                   .group('players.id, players.entrant_name')
                                   .order('tournament_count DESC')
                                   .limit(10)
      
      @most_active_players = active_players_data.map do |player_data|
        { name: player_data.entrant_name, participations: player_data.tournament_count }
      end
    rescue => e
      # Fallback en caso de error
      Rails.logger.error "Error in most active players query: #{e.message}"
      @most_active_players = [
        { name: "Error al cargar datos", participations: 0 }
      ]
    end
    
    # Distribución de tamaños de torneos
    @tournament_size_distribution = {
      'Pequeño (≤16)' => Tournament.where('attendees_count <= ?', 16).count,
      'Mediano (17-32)' => Tournament.where(attendees_count: 17..32).count,
      'Grande (33-64)' => Tournament.where(attendees_count: 33..64).count,
      'Muy Grande (65-128)' => Tournament.where(attendees_count: 65..128).count,
      'Masivo (>128)' => Tournament.where('attendees_count > ?', 128).count
    }
    
    # Eliminamos las estadísticas de videojuegos ya que serán 100% Smash
    
    # Crecimiento mensual de jugadores únicos (simplificado para SQLite)
    @unique_players_by_month = EventSeed.joins(:event)
                                      .where('events.created_at > ?', 1.year.ago)
                                      .group("strftime('%Y-%m', events.created_at)")
                                      .distinct
                                      .count(:player_id)
    
    # Torneos más grandes por región con nombres (simplificado)
    region_records = {}
    Tournament.where.not(attendees_count: nil).each do |tournament|
      region = tournament.region || 'Sin región'
      if !region_records[region] || tournament.attendees_count > region_records[region][2]
        region_records[region] = [region, tournament.name, tournament.attendees_count]
      end
    end
    @biggest_tournaments_by_region = region_records
    
    # Actividad reciente (últimos 30 días)
    @recent_tournaments = Tournament.where('created_at > ?', 30.days.ago).count
    @recent_events = Event.where('created_at > ?', 30.days.ago).count
    @recent_players = Player.where('created_at > ?', 30.days.ago).count
    
    # Debug logs
    puts "=== DEBUG STATS ==="
    puts "@tournaments_by_year: #{@tournaments_by_year.inspect}"
    puts "@tournaments_by_year class: #{@tournaments_by_year.class}"
    puts "@most_active_players: #{@most_active_players.inspect}"
    puts "@tournament_size_distribution: #{@tournament_size_distribution.inspect}"
  end
end 