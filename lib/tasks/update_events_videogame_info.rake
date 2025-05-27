namespace :events do
  desc "Actualizar información de videojuego en eventos existentes"
  task update_videogame_info: :environment do
    puts "🔄 Actualizando información de videojuego en eventos existentes..."
    
    # Obtener eventos que no tienen información de videojuego
    events_without_info = Event.where(videogame_id: nil)
    total_events = events_without_info.count
    
    if total_events == 0
      puts "✅ Todos los eventos ya tienen información de videojuego actualizada."
      return
    end
    
    puts "📊 Encontrados #{total_events} eventos sin información de videojuego"
    puts "🚀 Iniciando actualización desde la API de start.gg..."
    
    updated_count = 0
    error_count = 0
    
    # Procesar eventos por torneo para ser más eficiente
    tournaments_with_missing_info = events_without_info.joins(:tournament)
                                                      .distinct
                                                      .pluck('tournaments.slug')
    
    puts "🏆 Procesando #{tournaments_with_missing_info.count} torneos..."
    
    client = StartGgClient.new
    
    tournaments_with_missing_info.each_with_index do |tournament_slug, index|
      begin
        puts "   📥 Procesando torneo #{index + 1}/#{tournaments_with_missing_info.count}: #{tournament_slug}"
        
        # Obtener información de eventos del torneo desde la API
        events_data = StartGgQueries.fetch_tournament_events(client, tournament_slug)
        
        events_data.each do |event_data|
          # Buscar el evento correspondiente en la base de datos
          event = Event.joins(:tournament)
                      .where(tournaments: { slug: tournament_slug })
                      .where(slug: event_data['slug'])
                      .first
          
          next unless event && event.videogame_id.nil?
          
          # Actualizar información del videojuego
          event.update!(
            videogame_id: event_data.dig('videogame', 'id'),
            videogame_name: event_data.dig('videogame', 'name'),
            team_min_players: event_data.dig('teamRosterSize', 'minPlayers'),
            team_max_players: event_data.dig('teamRosterSize', 'maxPlayers')
          )
          
          updated_count += 1
          
          game_name = event.videogame_name || 'Desconocido'
          team_info = event.team_max_players ? " (#{event.team_min_players}-#{event.team_max_players} jugadores)" : ""
          puts "      ✅ #{event.name} → #{game_name}#{team_info}"
        end
        
        # Pausa para respetar rate limits
        sleep(2)
        
      rescue StandardError => e
        error_count += 1
        puts "      ❌ Error procesando torneo #{tournament_slug}: #{e.message}"
        
        # Si es rate limit, esperar más tiempo
        if e.message.include?('429')
          puts "      ⏱️ Rate limit detectado, esperando 60 segundos..."
          sleep(60)
        end
      end
    end
    
    puts ""
    puts "✅ Actualización completada!"
    puts "   📊 Eventos actualizados: #{updated_count}"
    puts "   ❌ Errores: #{error_count}"
    puts "   📈 Eventos restantes sin info: #{Event.where(videogame_id: nil).count}"
  end
end 