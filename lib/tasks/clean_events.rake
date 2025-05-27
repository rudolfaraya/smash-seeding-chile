namespace :events do
  desc "Limpiar eventos que no son de Smash Ultimate Singles"
  task clean_invalid: :environment do
    puts "🧹 Iniciando limpieza de eventos no válidos..."
    puts "   📊 Analizando eventos existentes en la base de datos..."
    
    # Mostrar estadísticas antes de la limpieza
    total_events = Event.count
    total_seeds = EventSeed.count
    
    puts "   📈 Estado actual:"
    puts "      - Eventos totales: #{total_events}"
    puts "      - Seeds totales: #{total_seeds}"
    
    # Ejecutar limpieza
    filter_service = EventFilterService.new
    results = filter_service.clean_invalid_existing_events
    
    # Mostrar estadísticas después de la limpieza
    final_events = Event.count
    final_seeds = EventSeed.count
    
    puts ""
    puts "✅ Limpieza completada!"
    puts "   📊 Resultados:"
    puts "      - Eventos eliminados: #{results[:deleted_events]}"
    puts "      - Seeds eliminados: #{results[:deleted_seeds]}"
    puts "      - Eventos restantes: #{final_events}"
    puts "      - Seeds restantes: #{final_seeds}"
    puts ""
    puts "💡 Los jugadores (Players) se mantuvieron intactos para preservar su historial."
  end

  desc "Mostrar estadísticas de eventos por tipo"
  task stats: :environment do
    puts "📊 Estadísticas de eventos en la base de datos:"
    puts ""
    
    total_events = Event.count
    total_tournaments = Tournament.count
    
    # Estadísticas usando información de videojuego (más precisas)
    smash_ultimate_events = Event.where(videogame_id: 1386).count
    other_game_events_by_id = Event.where.not(videogame_id: [nil, 1386]).count
    
    # Estadísticas usando información de equipo
    singles_by_team_size = Event.where('team_max_players IS NULL OR team_max_players <= 1').count
    doubles_by_team_size = Event.where('team_max_players > 1').count
    
    # Estadísticas por patrones de nombre (para eventos sin info de videojuego)
    events_without_videogame_info = Event.where(videogame_id: nil).count
    doubles_by_name = Event.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ? OR LOWER(name) LIKE ?", 
                                  '%doubles%', '%dobles%', '%teams%').count
    
    other_games_patterns = [
      '%tekken%', '%street fighter%', '%sf6%', '%guilty gear%', 
      '%dragon ball%', '%dbfz%', '%mortal kombat%', '%mk1%', '%mk11%',
      '%king of fighters%', '%kof%', '%blazblue%'
    ]
    
    other_games_by_name = Event.where(
      other_games_patterns.map { "LOWER(name) LIKE ?" }.join(" OR "),
      *other_games_patterns
    ).count
    
    # Eventos válidos de Smash Singles
    valid_smash_singles = Event.valid_smash_singles.count
    
    puts "   🏆 Torneos totales: #{total_tournaments}"
    puts "   🎮 Eventos totales: #{total_events}"
    puts ""
    puts "   📋 Por información de videojuego:"
    puts "      - Smash Ultimate: #{smash_ultimate_events}"
    puts "      - Otros juegos: #{other_game_events_by_id}"
    puts "      - Sin información: #{events_without_videogame_info}"
    puts ""
    puts "   👥 Por configuración de equipo:"
    puts "      - Singles (≤1 jugador): #{singles_by_team_size}"
    puts "      - Doubles (>1 jugador): #{doubles_by_team_size}"
    puts ""
    puts "   🎯 Eventos válidos de Smash Singles: #{valid_smash_singles}"
    puts "   📊 Eventos que requieren limpieza:"
    puts "      - Doubles por nombre: #{doubles_by_name}"
    puts "      - Otros juegos por nombre: #{other_games_by_name}"
    puts ""
    
    # Mostrar ejemplos de eventos que necesitan limpieza
    if doubles_by_name > 0
      puts "   📝 Ejemplos de eventos Doubles detectados por nombre:"
      Event.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ?", '%doubles%', '%dobles%')
           .limit(5).pluck(:name, :videogame_name).each do |name, game|
        game_info = game ? " (#{game})" : ""
        puts "      - #{name}#{game_info}"
      end
      puts ""
    end
    
    if other_games_by_name > 0
      puts "   📝 Ejemplos de eventos de otros juegos detectados por nombre:"
      Event.where(
        other_games_patterns.map { "LOWER(name) LIKE ?" }.join(" OR "),
        *other_games_patterns
      ).limit(5).pluck(:name, :videogame_name).each do |name, game|
        game_info = game ? " (#{game})" : ""
        puts "      - #{name}#{game_info}"
      end
    end
  end

  desc "Validar eventos específicos por torneo"
  task :validate, [:tournament_slug] => :environment do |task, args|
    unless args[:tournament_slug]
      puts "❌ Error: Debes proporcionar un slug de torneo"
      puts "Uso: rails events:validate[tournament-slug]"
      exit 1
    end
    
    tournament = Tournament.find_by(slug: args[:tournament_slug])
    unless tournament
      puts "❌ Error: Torneo con slug '#{args[:tournament_slug]}' no encontrado"
      exit 1
    end
    
    puts "🔍 Validando eventos del torneo: #{tournament.name}"
    puts "   📅 Fecha: #{tournament.start_at}"
    puts "   🌍 Ubicación: #{tournament.venue_address}"
    puts ""
    
    events = tournament.events.includes(:event_seeds)
    
    if events.empty?
      puts "⚠️ Este torneo no tiene eventos asociados"
      return
    end
    
    events.each do |event|
      seeds_count = event.event_seeds.count
      
      # Analizar si parece válido
      filter_service = EventFilterService.new
      is_doubles = filter_service.send(:doubles_event_by_name?, event.name)
      is_other_game = filter_service.send(:other_game_event_by_name?, event.name)
      
      status = if is_doubles
        "🔴 DOUBLES"
      elsif is_other_game
        "🟡 OTRO JUEGO"
      else
        "🟢 VÁLIDO"
      end
      
      puts "   #{status} #{event.name} (#{seeds_count} participantes)"
    end
  end
end 