namespace :debug do
  desc "Debuggear problemas de sincronización de eventos específicos"
  task :event_sync, [ :search_term ] => :environment do |task, args|
    search_term = args[:search_term]

    unless search_term
      puts "❌ Error: Debes proporcionar un término de búsqueda"
      puts "Uso: rails debug:event_sync['gourmet galaxy']"
      exit 1
    end

    puts "🔍 DEBUGGING: Sincronización de eventos"
    puts "Término de búsqueda: #{search_term}"
    puts "=" * 60

    # Buscar torneos que coincidan
    tournaments = Tournament.where("name LIKE ?", "%#{search_term}%")

    if tournaments.empty?
      puts "❌ No se encontraron torneos con el término: #{search_term}"
      exit 1
    end

    puts "📊 TORNEOS ENCONTRADOS: #{tournaments.count}"
    puts "-" * 40

    tournaments.each_with_index do |tournament, index|
      puts "\n#{index + 1}. #{tournament.name}"
      puts "   ID: #{tournament.id}"
      puts "   Slug: #{tournament.slug}"
      puts "   Start: #{tournament.start_at&.strftime('%Y-%m-%d')}"
      puts "   Eventos: #{tournament.events.count}"

      if tournament.events.any?
        puts "\n   📋 EVENTOS:"
        tournament.events.each_with_index do |event, e_index|
          seeds_count = event.event_seeds.count
          puts "   #{e_index + 1}. #{event.name}"
          puts "      ID: #{event.id}"
          puts "      Slug: #{event.slug}"
          puts "      start_gg_event_id: #{event.start_gg_event_id}"
          puts "      Seeds: #{seeds_count}"
          puts "      Última sync: #{event.seeds_last_synced_at&.strftime('%Y-%m-%d %H:%M') || 'Nunca'}"

          # Verificar si es un evento válido para seeds
          if event.videogame_id == Event::SMASH_ULTIMATE_VIDEOGAME_ID
            puts "      ✅ Evento de Smash Ultimate"
          else
            puts "      ❌ NO es evento de Smash Ultimate (videogame_id: #{event.videogame_id})"
          end

          if event.team_max_players.nil? || event.team_max_players <= 1
            puts "      ✅ Evento individual"
          else
            puts "      ❌ Evento de equipos (team_max_players: #{event.team_max_players})"
          end
        end
      else
        puts "   ⚠️ Sin eventos sincronizados"
      end
    end

    puts "\n" + "=" * 60
    puts "¿Deseas sincronizar seeds de algún evento? (evento_id/N): "

    event_id = STDIN.gets.chomp

    if event_id.match?(/^\d+$/)
      event = Event.find_by(id: event_id.to_i)

      if event
        puts "\n🔄 SINCRONIZANDO EVENTO: #{event.name}"
        puts "Torneo: #{event.tournament.name}"
        puts "Force: true (para debugging)"
        puts "Update Players: false"

        begin
          sync_service = SyncEventSeeds.new(event, force: true, update_players: false)
          sync_service.call

          event.reload
          seeds_captured = event.event_seeds.count

          puts "\n✅ SINCRONIZACIÓN COMPLETADA"
          puts "Seeds capturados: #{seeds_captured}"

          if seeds_captured > 0
            puts "\n📊 RESUMEN DE SEEDS:"
            event.event_seeds.limit(5).each do |seed|
              puts "  #{seed.seed_num}: #{seed.player.entrant_name}"
            end
            puts "  ... y #{[ seeds_captured - 5, 0 ].max} más" if seeds_captured > 5
          else
            puts "\n❌ No se capturaron seeds. Posibles causas:"
            puts "   - Evento no tiene participantes en start.gg"
            puts "   - Problemas de conectividad con la API"
            puts "   - Event slug o tournament slug incorrectos"
            puts "   - Evento no es público en start.gg"
          end

        rescue StandardError => e
          puts "\n❌ ERROR EN SINCRONIZACIÓN:"
          puts "   Error: #{e.message}"
          puts "   Backtrace: #{e.backtrace.first(3).join('\n   ')}"
        end
      else
        puts "❌ Evento con ID #{event_id} no encontrado"
      end
    else
      puts "✅ No se realizará sincronización"
    end
  end

  desc "Verificar estado de jobs pendientes/fallidos"
  task check_jobs: :environment do
    puts "🔍 VERIFICANDO ESTADO DE JOBS"
    puts "=" * 40

    begin
      # Intentar acceder a SolidQueue si está configurado
      if defined?(SolidQueue)
        pending_jobs = SolidQueue::Job.where(finished_at: nil).count
        failed_jobs = SolidQueue::FailedExecution.count

        puts "⏳ Jobs pendientes: #{pending_jobs}"
        puts "❌ Jobs fallidos: #{failed_jobs}"

        if failed_jobs > 0
          puts "\n📋 ÚLTIMOS JOBS FALLIDOS:"
          SolidQueue::FailedExecution.order(created_at: :desc).limit(5).each do |failed_job|
            puts "   - Job: #{failed_job.job_class} (#{failed_job.created_at.strftime('%Y-%m-%d %H:%M')})"
            puts "     Error: #{failed_job.error}"
          end
        end
      else
        puts "ℹ️ SolidQueue no está disponible o configurado"
      end
    rescue StandardError => e
      puts "❌ Error verificando jobs: #{e.message}"
    end
  end
end
