namespace :tournament do
  desc "Sincronizar eventos y seeds de un torneo específico respetando rate limits"
  task :sync_complete, [:tournament_id] => :environment do |task, args|
    if args[:tournament_id].blank?
      puts "❌ Error: Debes proporcionar un ID de torneo"
      puts "Uso: bin/rails tournament:sync_complete[TOURNAMENT_ID]"
      puts "Ejemplo: bin/rails tournament:sync_complete[12345]"
      exit 1
    end
    
    tournament_id = args[:tournament_id].to_i
    tournament = Tournament.find_by(id: tournament_id)
    
    unless tournament
      puts "❌ Error: Torneo con ID #{tournament_id} no encontrado"
      exit 1
    end
    
    puts "🚀 Iniciando sincronización completa del torneo: #{tournament.name}"
    puts "📅 Fecha: #{tournament.start_at&.strftime('%d/%m/%Y')}"
    puts "🏟️  Lugar: #{tournament.venue_address}"
    puts "=" * 80
    
    begin
      # Paso 1: Sincronizar eventos del torneo
      puts "\n📋 PASO 1: Sincronizando eventos del torneo..."
      
      events_antes = tournament.events.count
      puts "   Eventos actuales: #{events_antes}"
      
      service = SyncSmashData.new
      nuevos_eventos = service.sync_events_for_single_tournament(tournament)
      
      tournament.reload
      events_despues = tournament.events.count
      
      puts "   ✅ Eventos después: #{events_despues}"
      puts "   ➕ Nuevos eventos encontrados: #{nuevos_eventos}"
      
      if tournament.events.empty?
        puts "   ⚠️  No hay eventos para sincronizar seeds"
        puts "\n🎉 Proceso completado (sin eventos para procesar)"
        exit 0
      end
      
      # Paso 2: Sincronizar seeds de cada evento
      puts "\n🌱 PASO 2: Sincronizando seeds de cada evento..."
      puts "   Total de eventos a procesar: #{tournament.events.count}"
      puts "   ⏰ Rate limit: 80 requests/minuto (pausa de 5s entre eventos)"
      puts
      
      eventos_procesados = 0
      eventos_con_seeds = 0
      total_seeds = 0
      
      tournament.events.order(:name).each_with_index do |event, index|
        print "   #{index + 1}/#{tournament.events.count} - #{event.name}... "
        
        begin
          seeds_antes = event.event_seeds.count
          
          # Sincronizar seeds del evento
          sync_service = SyncEventSeeds.new(event)
          sync_service.call
          
          # Actualizar timestamp si está disponible
          if event.respond_to?(:seeds_last_synced_at)
            event.update(seeds_last_synced_at: Time.current)
          end
          
          event.reload
          seeds_despues = event.event_seeds.count
          nuevos_seeds = seeds_despues - seeds_antes
          
          if seeds_despues > 0
            eventos_con_seeds += 1
            total_seeds += seeds_despues
            puts "✅ #{seeds_despues} seeds (#{nuevos_seeds} nuevos)"
          else
            puts "⚠️  Sin seeds disponibles"
          end
          
          eventos_procesados += 1
          
          # Pausa para respetar rate limit (excepto en el último evento)
          unless index == tournament.events.count - 1
            print "      ⏳ Esperando 5 segundos (rate limit)..."
            sleep(5)
            puts " ✓"
          end
          
        rescue => e
          puts "❌ Error: #{e.message}"
          puts "      Continuando con el siguiente evento..."
          
          # Pausa más larga en caso de error
          unless index == tournament.events.count - 1
            print "      ⏳ Esperando 10 segundos (error recovery)..."
            sleep(10)
            puts " ✓"
          end
        end
      end
      
      # Resumen final
      puts "\n" + "=" * 80
      puts "🎉 SINCRONIZACIÓN COMPLETADA"
      puts "=" * 80
      puts "🏆 Torneo: #{tournament.name}"
      puts "📋 Eventos procesados: #{eventos_procesados}/#{tournament.events.count}"
      puts "🌱 Eventos con seeds: #{eventos_con_seeds}"
      puts "🎯 Total de seeds sincronizados: #{total_seeds}"
      puts "⏰ Tiempo estimado: ~#{(tournament.events.count * 5)} segundos (rate limit)"
      
      if eventos_con_seeds < tournament.events.count
        puts "\n⚠️  NOTA: Algunos eventos no tienen seeds disponibles"
        puts "   Esto puede ser normal si el torneo aún no ha comenzado"
        puts "   o si algunos eventos no tienen participantes registrados"
      end
      
      puts "\n✅ Proceso completado exitosamente"
      
    rescue => e
      puts "\n❌ ERROR FATAL durante la sincronización:"
      puts "   #{e.message}"
      puts "   #{e.backtrace.first}"
      exit 1
    end
  end
  
  desc "Mostrar información de un torneo"
  task :info, [:tournament_id] => :environment do |task, args|
    if args[:tournament_id].blank?
      puts "❌ Error: Debes proporcionar un ID de torneo"
      puts "Uso: bin/rails tournament:info[TOURNAMENT_ID]"
      exit 1
    end
    
    tournament = Tournament.find_by(id: args[:tournament_id].to_i)
    
    unless tournament
      puts "❌ Error: Torneo con ID #{args[:tournament_id]} no encontrado"
      exit 1
    end
    
    puts "📊 INFORMACIÓN DEL TORNEO"
    puts "=" * 50
    puts "🏆 Nombre: #{tournament.name}"
    puts "🆔 ID: #{tournament.id}"
    puts "📅 Fecha: #{tournament.start_at&.strftime('%d/%m/%Y %H:%M')}"
    puts "🏟️  Lugar: #{tournament.venue_address}"
    puts "🌍 Ciudad: #{tournament.city || 'No parseada'}"
    puts "🗺️  Región: #{tournament.region || 'No parseada'}"
    puts "📋 Total eventos: #{tournament.events.count}"
    
    if tournament.events.any?
      puts "\n📋 EVENTOS:"
      tournament.events.order(:name).each_with_index do |event, index|
        seeds_count = event.event_seeds.count
        last_sync = event.respond_to?(:seeds_last_synced_at) && event.seeds_last_synced_at ? 
                   event.seeds_last_synced_at.strftime('%d/%m/%Y %H:%M') : 'Nunca'
        
        puts "   #{index + 1}. #{event.name}"
        puts "      🌱 Seeds: #{seeds_count}"
        puts "      🕐 Última sync: #{last_sync}"
      end
      
      total_seeds = tournament.events.sum { |e| e.event_seeds.count }
      puts "\n🎯 Total seeds: #{total_seeds}"
    else
      puts "\n⚠️  No hay eventos registrados"
    end
  end
  
  desc "Buscar torneo por nombre"
  task :search, [:query] => :environment do |task, args|
    if args[:query].blank?
      puts "❌ Error: Debes proporcionar un término de búsqueda"
      puts "Uso: bin/rails tournament:search['nombre del torneo']"
      exit 1
    end
    
    query = args[:query]
    tournaments = Tournament.where("LOWER(name) LIKE LOWER(?)", "%#{query}%")
                           .order(start_at: :desc)
                           .limit(10)
    
    if tournaments.empty?
      puts "❌ No se encontraron torneos con '#{query}'"
      exit 0
    end
    
    puts "🔍 RESULTADOS DE BÚSQUEDA: '#{query}'"
    puts "=" * 60
    
    tournaments.each_with_index do |tournament, index|
      puts "#{index + 1}. 🏆 #{tournament.name}"
      puts "   🆔 ID: #{tournament.id}"
      puts "   📅 Fecha: #{tournament.start_at&.strftime('%d/%m/%Y')}"
      puts "   🏟️  Lugar: #{tournament.venue_address}"
      puts "   📋 Eventos: #{tournament.events.count}"
      puts
    end
    
    puts "💡 Para sincronizar un torneo usa:"
    puts "   bin/rails tournament:sync_complete[ID_DEL_TORNEO]"
  end
end 