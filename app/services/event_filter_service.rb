class EventFilterService
  SMASH_ULTIMATE_VIDEOGAME_ID = 1386

  def initialize
    @filtered_events_count = 0
    @deleted_events_count = 0
    @deleted_seeds_count = 0
  end

  # Identificar si un evento es válido para nuestro propósito (Smash Ultimate Singles)
  def self.valid_smash_singles_event?(event_data)
    return false unless event_data['videogame']

    # 1. Verificar que sea Smash Ultimate
    videogame_id = event_data['videogame']['id'].to_i
    return false unless videogame_id == SMASH_ULTIMATE_VIDEOGAME_ID

    # 2. Verificar que no sea un evento de equipo (doubles)
    team_roster_size = event_data['teamRosterSize']
    if team_roster_size
      max_players = team_roster_size['maxPlayers'].to_i
      min_players = team_roster_size['minPlayers'].to_i
      
      # Si requiere más de 1 jugador por equipo, es doubles
      return false if max_players > 1 || min_players > 1
    end

    # 3. Verificar por nombre del evento (patrones comunes de doubles)
    event_name = event_data['name'].to_s.downcase
    doubles_patterns = [
      'doubles', 'dobles', 'teams', 'equipos', '2v2', 'duos', 'crew battle', 'crew'
    ]
    
    doubles_patterns.each do |pattern|
      return false if event_name.include?(pattern)
    end

    true
  end

  # Filtrar eventos durante la sincronización
  def filter_events_during_sync(events_data)
    valid_events = []
    
    events_data.each do |event_data|
      if self.class.valid_smash_singles_event?(event_data)
        valid_events << event_data
      else
        @filtered_events_count += 1
        videogame_name = event_data.dig('videogame', 'name') || 'Desconocido'
        team_info = event_data['teamRosterSize'] ? 
          " (min: #{event_data['teamRosterSize']['minPlayers']}, max: #{event_data['teamRosterSize']['maxPlayers']})" : ''
        
        Rails.logger.info "🚫 Evento filtrado: #{event_data['name']} - Videojuego: #{videogame_name}#{team_info}"
      end
    end

    Rails.logger.info "✅ Filtrados #{@filtered_events_count} eventos no válidos de #{events_data.size} eventos totales"
    valid_events
  end

  # Limpiar eventos existentes que no son válidos
  def clean_invalid_existing_events
    Rails.logger.info "🧹 Iniciando limpieza de eventos no válidos en la base de datos..."

    # Identificar eventos no válidos usando información de la BD y patrones de nombre
    invalid_events = []
    
    Event.includes(:tournament, :event_seeds).find_each do |event|
      if invalid_existing_event?(event)
        invalid_events << event
      end
    end

    # Separar eventos por tipo para tratarlos de manera diferente
    doubles_events = invalid_events.select { |e| is_doubles_event?(e) }
    other_game_events = invalid_events.select { |e| is_other_game_event?(e) }

    # Eliminar eventos de doubles (conservar players)
    delete_doubles_events(doubles_events) if doubles_events.any?

    # Eliminar eventos de otros juegos (eliminar players asociados también)
    delete_other_game_events(other_game_events) if other_game_events.any?
    
    Rails.logger.info "✅ Limpieza completada. Eliminados #{@deleted_events_count} eventos y #{@deleted_seeds_count} seeds"
    
    {
      deleted_events: @deleted_events_count,
      deleted_seeds: @deleted_seeds_count
    }
  end

  private

  def invalid_existing_event?(event)
    is_doubles_event?(event) || is_other_game_event?(event)
  end

  def is_doubles_event?(event)
    # Usar información de la BD si está disponible
    return event.doubles_event? if event.videogame_id.present? && event.team_max_players.present?
    
    # Fallback a patrones de nombre
    doubles_event_by_name?(event.name)
  end

  def is_other_game_event?(event)
    # Usar información de la BD si está disponible
    return event.other_game_event? if event.videogame_id.present?
    
    # Fallback a patrones de nombre
    other_game_event_by_name?(event.name)
  end

  def doubles_event_by_name?(event_name)
    name = event_name.to_s.downcase
    doubles_patterns = [
      'doubles', 'dobles', 'teams', 'equipos', '2v2', 'duos',
      'crew battle', 'crew', 'squads', 'squad'
    ]
    
    doubles_patterns.any? { |pattern| name.include?(pattern) }
  end

  def other_game_event_by_name?(event_name)
    name = event_name.to_s.downcase
    other_game_patterns = [
      'tekken', 'street fighter', 'sf6', 'guilty gear', 'gg',
      'dragon ball', 'dbfz', 'mortal kombat', 'mk1', 'mk11',
      'king of fighters', 'kof', 'blazblue', 'granblue',
      'soul calibur', 'injustice', 'marvel', 'mvci'
    ]
    
    other_game_patterns.any? { |pattern| name.include?(pattern) }
  end

  def delete_doubles_events(doubles_events)
    return if doubles_events.empty?

    Rails.logger.info "🗑️ Eliminando #{doubles_events.size} eventos de doubles (conservando players)..."

    doubles_events.each do |event|
      seeds_count = event.event_seeds.count
      
      # Solo eliminar los seeds, no los players
      event.event_seeds.destroy_all
      @deleted_seeds_count += seeds_count
      
      # Eliminar el evento
      event.destroy
      @deleted_events_count += 1
      
      Rails.logger.info "   ❌ Eliminado evento doubles: #{event.name} (#{seeds_count} seeds)"
    end
  end

  def delete_other_game_events(other_game_events)
    return if other_game_events.empty?

    Rails.logger.info "🗑️ Eliminando #{other_game_events.size} eventos de otros juegos..."

    other_game_events.each do |event|
      seeds_count = event.event_seeds.count
      game_name = event.videogame_name || "Juego desconocido"
      
      # Para eventos de otros juegos, eliminar seeds y el evento
      # Los players se mantienen por si participaron en eventos de Smash
      event.event_seeds.destroy_all
      @deleted_seeds_count += seeds_count
      
      event.destroy
      @deleted_events_count += 1
      
      Rails.logger.info "   ❌ Eliminado evento de #{game_name}: #{event.name} (#{seeds_count} seeds)"
    end
  end
end 