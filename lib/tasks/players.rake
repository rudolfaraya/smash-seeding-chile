namespace :players do
  desc "Actualizar información de jugadores desde start.gg API"
  task update_from_api: :environment do
    puts "🚀 Iniciando actualización masiva de jugadores desde start.gg API"
    
    # Obtener jugadores que necesitan actualización
    players_to_update = Player.where("updated_at < ? OR name IS NULL OR country IS NULL", 30.days.ago)
    total_players = players_to_update.count
    
    puts "📊 Jugadores que necesitan actualización: #{total_players}"
    
    if total_players == 0
      puts "✅ Todos los jugadores están actualizados"
      exit
    end
    
    updated_count = 0
    failed_count = 0
    skipped_count = 0
    
    players_to_update.find_each.with_index do |player, index|
      puts "\n🔄 Procesando jugador #{index + 1}/#{total_players}: #{player.entrant_name} (ID: #{player.user_id})"
      
      if player.user_id.nil?
        puts "⚠️ Saltando jugador sin user_id: #{player.entrant_name}"
        skipped_count += 1
        next
      end
      
      begin
        if player.update_from_start_gg_api
          updated_count += 1
          puts "✅ Actualizado: #{player.entrant_name}"
        else
          failed_count += 1
          puts "❌ Falló: #{player.entrant_name}"
        end
        
        # Pausa para evitar rate limits
        sleep(2) if (index + 1) % 10 == 0 # Pausa más larga cada 10 jugadores
        sleep(0.5) # Pausa corta entre cada jugador
        
      rescue StandardError => e
        failed_count += 1
        puts "💥 Error procesando #{player.entrant_name}: #{e.message}"
        
        # Pausa más larga si hay error (posible rate limit)
        sleep(5)
      end
    end
    
    puts "\n🎉 Actualización completada!"
    puts "📈 Resumen:"
    puts "   • Total procesados: #{total_players}"
    puts "   • Actualizados exitosamente: #{updated_count}"
    puts "   • Fallidos: #{failed_count}"
    puts "   • Saltados (sin user_id): #{skipped_count}"
    puts "   • Tasa de éxito: #{((updated_count.to_f / (total_players - skipped_count)) * 100).round(1)}%" if total_players > skipped_count
  end

  desc "Actualizar solo jugadores con información incompleta"
  task update_incomplete: :environment do
    puts "🔍 Actualizando solo jugadores con información incompleta"
    
    # Jugadores sin nombre completo, país, o información básica
    incomplete_players = Player.where(
      "name IS NULL OR name = '' OR country IS NULL OR country = '' OR twitter_handle IS NULL"
    ).where.not(user_id: nil)
    
    total_players = incomplete_players.count
    puts "📊 Jugadores con información incompleta: #{total_players}"
    
    if total_players == 0
      puts "✅ Todos los jugadores tienen información completa"
      exit
    end
    
    updated_count = 0
    failed_count = 0
    
    incomplete_players.find_each.with_index do |player, index|
      puts "\n🔄 Procesando #{index + 1}/#{total_players}: #{player.entrant_name}"
      
      begin
        if player.update_from_start_gg_api
          updated_count += 1
          puts "✅ Información completada para: #{player.entrant_name}"
        else
          failed_count += 1
          puts "❌ No se pudo actualizar: #{player.entrant_name}"
        end
        
        sleep(1) # Pausa entre jugadores
        
      rescue StandardError => e
        failed_count += 1
        puts "💥 Error: #{e.message}"
        sleep(3)
      end
    end
    
    puts "\n🎉 Actualización de información incompleta completada!"
    puts "📈 Resumen:"
    puts "   • Total procesados: #{total_players}"
    puts "   • Actualizados: #{updated_count}"
    puts "   • Fallidos: #{failed_count}"
  end

  desc "Actualizar jugadores específicos por IDs"
  task :update_specific, [:player_ids] => :environment do |t, args|
    if args[:player_ids].blank?
      puts "❌ Debes proporcionar IDs de jugadores separados por comas"
      puts "Ejemplo: rake players:update_specific[1,2,3]"
      exit
    end
    
    player_ids = args[:player_ids].split(',').map(&:strip).map(&:to_i)
    puts "🎯 Actualizando jugadores específicos: #{player_ids.join(', ')}"
    
    players = Player.where(id: player_ids)
    found_count = players.count
    
    puts "📊 Jugadores encontrados: #{found_count}/#{player_ids.count}"
    
    if found_count == 0
      puts "❌ No se encontraron jugadores con esos IDs"
      exit
    end
    
    updated_count = 0
    failed_count = 0
    
    players.each_with_index do |player, index|
      puts "\n🔄 Actualizando #{index + 1}/#{found_count}: #{player.entrant_name}"
      
      begin
        if player.update_from_start_gg_api
          updated_count += 1
          puts "✅ Actualizado: #{player.entrant_name}"
        else
          failed_count += 1
          puts "❌ Falló: #{player.entrant_name}"
        end
        
        sleep(1)
        
      rescue StandardError => e
        failed_count += 1
        puts "💥 Error: #{e.message}"
      end
    end
    
    puts "\n🎉 Actualización específica completada!"
    puts "📈 Resumen:"
    puts "   • Actualizados: #{updated_count}"
    puts "   • Fallidos: #{failed_count}"
  end

  desc "Mostrar estadísticas de jugadores"
  task stats: :environment do
    total_players = Player.count
    players_with_complete_info = Player.where.not(
      name: [nil, '']
    ).where.not(
      country: [nil, '']
    ).count
    
    players_with_twitter = Player.where.not(twitter_handle: [nil, '']).count
    players_updated_recently = Player.where('updated_at > ?', 30.days.ago).count
    players_needing_update = Player.where('updated_at < ? OR name IS NULL OR country IS NULL', 30.days.ago).count
    
    puts "📊 Estadísticas de Jugadores"
    puts "=" * 40
    puts "Total de jugadores: #{total_players}"
    puts "Con información completa: #{players_with_complete_info} (#{((players_with_complete_info.to_f / total_players) * 100).round(1)}%)"
    puts "Con Twitter: #{players_with_twitter} (#{((players_with_twitter.to_f / total_players) * 100).round(1)}%)"
    puts "Actualizados recientemente (30 días): #{players_updated_recently}"
    puts "Necesitan actualización: #{players_needing_update}"
    puts "=" * 40
  end

  desc "Actualizar jugadores en lotes (recomendado para grandes cantidades)"
  task update_in_batches: :environment do
    puts "🚀 Iniciando actualización de jugadores en lotes"
    
    service = UpdatePlayersService.new(
      batch_size: 25,
      delay_between_batches: 45.seconds,
      delay_between_requests: 2.seconds,
      force_update: false
    )
    
    results = service.update_players_in_batches
    
    puts "\n🎉 Actualización en lotes completada!"
    puts "📈 Resumen final:"
    puts "   • Total procesados: #{results[:total]}"
    puts "   • Actualizados exitosamente: #{results[:updated]}"
    puts "   • Fallidos: #{results[:failed]}"
    puts "   • Saltados: #{results[:skipped]}"
    puts "   • Lotes procesados: #{results[:batches_processed]}"
    puts "   • Tasa de éxito: #{((results[:updated].to_f / (results[:total] - results[:skipped])) * 100).round(1)}%" if results[:total] > results[:skipped]
  end

  desc "Forzar actualización de todos los jugadores en lotes"
  task force_update_all: :environment do
    puts "⚠️ ATENCIÓN: Esta tarea actualizará TODOS los jugadores desde la API"
    puts "Esto puede tomar mucho tiempo y consumir muchas requests de la API"
    print "¿Estás seguro? (y/N): "
    
    confirmation = STDIN.gets.chomp.downcase
    unless confirmation == 'y' || confirmation == 'yes'
      puts "❌ Operación cancelada"
      exit
    end
    
    puts "🚀 Iniciando actualización forzada de TODOS los jugadores"
    
    service = UpdatePlayersService.new(
      batch_size: 20,
      delay_between_batches: 60.seconds,
      delay_between_requests: 3.seconds,
      force_update: true
    )
    
    results = service.update_players_in_batches
    
    puts "\n🎉 Actualización forzada completada!"
    puts "📈 Resumen final:"
    puts "   • Total procesados: #{results[:total]}"
    puts "   • Actualizados exitosamente: #{results[:updated]}"
    puts "   • Fallidos: #{results[:failed]}"
    puts "   • Saltados: #{results[:skipped]}"
    puts "   • Lotes procesados: #{results[:batches_processed]}"
  end

  desc "Sincronizar torneos con actualización automática de jugadores"
  task sync_tournaments_with_player_update: :environment do
    puts "🚀 Sincronizando torneos con actualización automática de jugadores"
    
    sync_service = SyncSmashData.new(update_players: true)
    nuevos_torneos = sync_service.sync_tournaments_and_events_atomic
    
    puts "✅ Sincronización completada con #{nuevos_torneos} nuevos torneos"
    puts "Los jugadores de los nuevos torneos han sido actualizados automáticamente"
  end

  desc "Programar actualización de jugadores en background"
  task schedule_update: :environment do
    puts "📅 Programando actualización de jugadores en background"
    
    job = UpdatePlayersJob.perform_later(
      batch_size: 30,
      delay_between_batches: 60.seconds,
      delay_between_requests: 2.seconds,
      force_update: false
    )
    
    puts "✅ Job programado con ID: #{job.job_id}"
    puts "La actualización se ejecutará en background"
    puts "Puedes revisar el progreso en los logs de la aplicación"
  end

  desc "Programar actualización forzada de todos los jugadores"
  task schedule_force_update: :environment do
    puts "⚠️ ATENCIÓN: Esta tarea programará la actualización de TODOS los jugadores"
    print "¿Estás seguro? (y/N): "
    
    confirmation = STDIN.gets.chomp.downcase
    unless confirmation == 'y' || confirmation == 'yes'
      puts "❌ Operación cancelada"
      exit
    end
    
    puts "📅 Programando actualización forzada en background"
    
    job = UpdatePlayersJob.perform_later(
      batch_size: 20,
      delay_between_batches: 90.seconds,
      delay_between_requests: 3.seconds,
      force_update: true
    )
    
    puts "✅ Job de actualización forzada programado con ID: #{job.job_id}"
    puts "La actualización se ejecutará en background"
  end

  desc "Probar actualización de entrant_name para jugadores específicos"
  task :test_entrant_name_update, [:player_ids] => :environment do |t, args|
    if args[:player_ids].blank?
      puts "❌ Debes proporcionar IDs de jugadores separados por comas"
      puts "Ejemplo: rake players:test_entrant_name_update[1,2,3]"
      exit
    end
    
    player_ids = args[:player_ids].split(',').map(&:strip).map(&:to_i)
    puts "🧪 Probando actualización de entrant_name para jugadores: #{player_ids.join(', ')}"
    
    players = Player.where(id: player_ids)
    found_count = players.count
    
    puts "📊 Jugadores encontrados: #{found_count}/#{player_ids.count}"
    
    if found_count == 0
      puts "❌ No se encontraron jugadores con esos IDs"
      exit
    end
    
    players.each_with_index do |player, index|
      puts "\n" + "="*60
      puts "🔄 Probando #{index + 1}/#{found_count}: #{player.entrant_name} (ID: #{player.id})"
      puts "📋 Información actual:"
      puts "   • Entrant Name: #{player.entrant_name}"
      puts "   • Name: #{player.name}"
      puts "   • User ID: #{player.user_id}"
      puts "   • Última actualización: #{player.updated_at}"
      
      if player.user_id.nil?
        puts "⚠️ Saltando jugador sin user_id"
        next
      end
      
      begin
        # Probar solo la obtención del tag reciente
        client = StartGgClient.new
        recent_tag = StartGgQueries.fetch_user_recent_tag(client, player.user_id)
        
        puts "\n🏷️ Tag reciente obtenido desde API: #{recent_tag || 'No encontrado'}"
        
        if recent_tag.present? && recent_tag != player.entrant_name
          puts "🔄 El tag ha cambiado de '#{player.entrant_name}' a '#{recent_tag}'"
          
          print "¿Actualizar el entrant_name? (y/N): "
          confirmation = STDIN.gets.chomp.downcase
          
          if confirmation == 'y' || confirmation == 'yes'
            old_name = player.entrant_name
            if player.update_from_start_gg_api
              puts "✅ Actualización exitosa!"
              puts "   • Entrant Name anterior: #{old_name}"
              puts "   • Entrant Name nuevo: #{player.reload.entrant_name}"
            else
              puts "❌ Error en la actualización"
            end
          else
            puts "⏭️ Actualización saltada por el usuario"
          end
        elsif recent_tag.present?
          puts "✅ El tag actual está correcto: #{recent_tag}"
        else
          puts "⚠️ No se pudo obtener el tag reciente desde la API"
        end
        
        sleep(2) # Pausa entre jugadores
        
      rescue StandardError => e
        puts "💥 Error: #{e.message}"
        puts "🔍 Backtrace: #{e.backtrace.first(3).join(', ')}"
      end
    end
    
    puts "\n🎉 Prueba de actualización de entrant_name completada!"
  end
end 