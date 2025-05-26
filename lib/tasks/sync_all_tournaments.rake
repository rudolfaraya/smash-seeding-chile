namespace :tournaments do
  desc "Sincronizar eventos y seeds de todos los torneos que falten, respetando rate limits"
  task :sync_all_missing, [ :limit ] => :environment do |task, args|
    limit = args[:limit]&.to_i || nil

    puts "🚀 SINCRONIZACIÓN MASIVA DE TORNEOS"
    puts "=" * 80
    puts "🔍 Analizando torneos que necesitan sincronización..."

    # Identificar torneos que necesitan eventos
    torneos_sin_eventos = Tournament.left_joins(:events)
                                  .where(events: { id: nil })
                                  .order(start_at: :desc)

    # Identificar torneos con eventos pero que necesitan seeds
    torneos_con_eventos_sin_seeds = Tournament.joins(:events)
                                            .where.not(id: Tournament.joins(events: :event_seeds)
                                                                   .distinct.pluck(:id))
                                            .distinct
                                            .order(start_at: :desc)

    # Identificar torneos con eventos parcialmente sincronizados
    torneos_parcialmente_sincronizados = Tournament.joins(:events)
                                                  .where(
                                                    id: Tournament.joins(:events)
                                                                 .group(:id)
                                                                 .having("COUNT(events.id) > COUNT(DISTINCT event_seeds.event_id)")
                                                                 .left_joins(events: :event_seeds)
                                                                 .pluck(:id)
                                                  )
                                                  .distinct
                                                  .order(start_at: :desc)

    total_candidatos = (torneos_sin_eventos.pluck(:id) +
                       torneos_con_eventos_sin_seeds.pluck(:id) +
                       torneos_parcialmente_sincronizados.pluck(:id)).uniq.count

    puts "📊 ANÁLISIS INICIAL:"
    puts "   🔸 Torneos sin eventos: #{torneos_sin_eventos.count}"
    puts "   🔸 Torneos con eventos sin seeds: #{torneos_con_eventos_sin_seeds.count}"
    puts "   🔸 Torneos parcialmente sincronizados: #{torneos_parcialmente_sincronizados.count}"
    puts "   📋 Total candidatos únicos: #{total_candidatos}"

    if limit
      puts "   ⚡ Límite aplicado: #{limit} torneos"
    end

    if total_candidatos == 0
      puts "\n✅ ¡Todos los torneos están sincronizados!"
      exit 0
    end

    # Combinar y eliminar duplicados, aplicar límite
    todos_los_candidatos = [
      *torneos_sin_eventos,
      *torneos_con_eventos_sin_seeds,
      *torneos_parcialmente_sincronizados
    ].uniq { |t| t.id }.sort_by(&:start_at).reverse

    torneos_a_procesar = limit ? todos_los_candidatos.first(limit) : todos_los_candidatos

    puts "\n🎯 PROCESANDO #{torneos_a_procesar.count} TORNEOS"
    puts "⏰ Tiempo estimado: ~#{estimate_time(torneos_a_procesar)} minutos"
    puts "=" * 80

    # Estadísticas globales
    torneos_procesados = 0
    eventos_sincronizados = 0
    seeds_sincronizados = 0
    errores = 0
    inicio_proceso = Time.current

    torneos_a_procesar.each_with_index do |tournament, index|
      puts "\n🏆 #{index + 1}/#{torneos_a_procesar.count} - #{tournament.name}"
      puts "   📅 #{tournament.start_at&.strftime('%d/%m/%Y')}"
      puts "   🏟️  #{tournament.venue_address}"

      begin
        # Paso 1: Sincronizar eventos si es necesario
        events_antes = tournament.events.count
        eventos_nuevos = 0

        if events_antes == 0
          puts "   📋 Sincronizando eventos..."
          service = SyncSmashData.new
          eventos_nuevos = service.sync_events_for_single_tournament(tournament)
          tournament.reload
          puts "      ✅ #{tournament.events.count} eventos encontrados (#{eventos_nuevos} nuevos)"
          eventos_sincronizados += eventos_nuevos
        else
          puts "   📋 Eventos ya sincronizados: #{events_antes}"
        end

        # Paso 2: Sincronizar seeds de eventos que los necesiten
        if tournament.events.any?
          eventos_sin_seeds = tournament.events.left_joins(:event_seeds)
                                              .where(event_seeds: { id: nil })

          eventos_con_pocos_seeds = tournament.events.joins(:event_seeds)
                                                    .group("events.id")
                                                    .having("COUNT(event_seeds.id) < 5")
                                                    .pluck("events.id")
                                                    .then { |ids| tournament.events.where(id: ids) }

          eventos_a_sincronizar = (eventos_sin_seeds.to_a + eventos_con_pocos_seeds.to_a).uniq

          if eventos_a_sincronizar.any?
            puts "   🌱 Sincronizando seeds de #{eventos_a_sincronizar.count} eventos..."

            eventos_a_sincronizar.each_with_index do |event, event_index|
              print "      #{event_index + 1}/#{eventos_a_sincronizar.count} - #{event.name}... "

              begin
                seeds_antes = event.event_seeds.count

                sync_service = SyncEventSeeds.new(event)
                sync_service.call

                if event.respond_to?(:seeds_last_synced_at)
                  event.update(seeds_last_synced_at: Time.current)
                end

                event.reload
                seeds_despues = event.event_seeds.count
                seeds_nuevos = seeds_despues - seeds_antes

                if seeds_despues > 0
                  puts "✅ #{seeds_despues} seeds (#{seeds_nuevos} nuevos)"
                  seeds_sincronizados += seeds_nuevos
                else
                  puts "⚠️  Sin seeds"
                end

                # Rate limit entre eventos
                unless event_index == eventos_a_sincronizar.count - 1
                  sleep(3) # 3 segundos entre eventos del mismo torneo
                end

              rescue => e
                puts "❌ Error: #{e.message[0..50]}..."
                errores += 1
                sleep(5) # Pausa más larga en error
              end
            end
          else
            puts "   🌱 Seeds ya sincronizados"
          end
        end

        torneos_procesados += 1

        # Pausa entre torneos (excepto el último)
        unless index == torneos_a_procesar.count - 1
          print "   ⏳ Pausa entre torneos (10s)..."
          sleep(10)
          puts " ✓"
        end

      rescue => e
        puts "   ❌ ERROR FATAL: #{e.message}"
        errores += 1
        # Pausa más larga en error fatal
        sleep(15) unless index == torneos_a_procesar.count - 1
      end
    end

    # Resumen final
    tiempo_total = ((Time.current - inicio_proceso) / 60).round(1)

    puts "\n" + "=" * 80
    puts "🎉 SINCRONIZACIÓN MASIVA COMPLETADA"
    puts "=" * 80
    puts "📊 ESTADÍSTICAS FINALES:"
    puts "   🏆 Torneos procesados: #{torneos_procesados}/#{torneos_a_procesar.count}"
    puts "   📋 Eventos sincronizados: #{eventos_sincronizados}"
    puts "   🌱 Seeds sincronizados: #{seeds_sincronizados}"
    puts "   ❌ Errores encontrados: #{errores}"
    puts "   ⏰ Tiempo total: #{tiempo_total} minutos"

    if errores > 0
      puts "\n⚠️  Se encontraron #{errores} errores durante el proceso"
      puts "   Puedes volver a ejecutar el comando para reintentar los fallidos"
    end

    puts "\n✅ Proceso completado"
  end

  desc "Mostrar estadísticas de sincronización de todos los torneos"
  task sync_stats: :environment do
    puts "📊 ESTADÍSTICAS DE SINCRONIZACIÓN"
    puts "=" * 60

    total_tournaments = Tournament.count
    tournaments_with_events = Tournament.joins(:events).distinct.count
    tournaments_without_events = total_tournaments - tournaments_with_events

    tournaments_with_seeds = Tournament.joins(events: :event_seeds).distinct.count
    tournaments_without_seeds = tournaments_with_events - tournaments_with_seeds

    total_events = Event.count
    events_with_seeds = Event.joins(:event_seeds).distinct.count
    events_without_seeds = total_events - events_with_seeds

    total_seeds = EventSeed.count

    puts "🏆 TORNEOS:"
    puts "   📊 Total: #{total_tournaments}"
    puts "   ✅ Con eventos: #{tournaments_with_events} (#{percentage(tournaments_with_events, total_tournaments)}%)"
    puts "   ❌ Sin eventos: #{tournaments_without_events} (#{percentage(tournaments_without_events, total_tournaments)}%)"
    puts "   ✅ Con seeds: #{tournaments_with_seeds} (#{percentage(tournaments_with_seeds, total_tournaments)}%)"
    puts "   ❌ Sin seeds: #{tournaments_without_seeds} (#{percentage(tournaments_without_seeds, total_tournaments)}%)"

    puts "\n📋 EVENTOS:"
    puts "   📊 Total: #{total_events}"
    puts "   ✅ Con seeds: #{events_with_seeds} (#{percentage(events_with_seeds, total_events)}%)"
    puts "   ❌ Sin seeds: #{events_without_seeds} (#{percentage(events_without_seeds, total_events)}%)"

    puts "\n🌱 SEEDS:"
    puts "   📊 Total: #{total_seeds}"

    if tournaments_without_events > 0 || tournaments_without_seeds > 0
      puts "\n💡 RECOMENDACIÓN:"
      puts "   Ejecuta: bin/rails tournaments:sync_all_missing"
      if tournaments_without_events + tournaments_without_seeds > 50
        puts "   O con límite: bin/rails tournaments:sync_all_missing[50]"
      end
    else
      puts "\n✅ ¡Todos los torneos están sincronizados!"
    end
  end

  desc "Listar torneos que necesitan sincronización"
  task list_missing: :environment do
    puts "📋 TORNEOS QUE NECESITAN SINCRONIZACIÓN"
    puts "=" * 60

    # Torneos sin eventos
    without_events = Tournament.left_joins(:events)
                              .where(events: { id: nil })
                              .order(start_at: :desc)
                              .limit(20)

    if without_events.any?
      puts "\n❌ SIN EVENTOS (#{without_events.count} torneos):"
      without_events.each_with_index do |t, i|
        puts "   #{i+1}. #{t.name} (ID: #{t.id}) - #{t.start_at&.strftime('%d/%m/%Y')}"
      end
    end

    # Torneos sin seeds
    without_seeds = Tournament.joins(:events)
                             .where.not(id: Tournament.joins(events: :event_seeds).distinct.pluck(:id))
                             .distinct
                             .order(start_at: :desc)
                             .limit(20)

    if without_seeds.any?
      puts "\n🌱 CON EVENTOS PERO SIN SEEDS (#{without_seeds.count} torneos):"
      without_seeds.each_with_index do |t, i|
        puts "   #{i+1}. #{t.name} (ID: #{t.id}) - #{t.events.count} eventos"
      end
    end

    total_missing = (without_events.pluck(:id) + without_seeds.pluck(:id)).uniq.count

    if total_missing == 0
      puts "\n✅ ¡Todos los torneos están sincronizados!"
    else
      puts "\n💡 Para sincronizar todos: bin/rails tournaments:sync_all_missing"
    end
  end

  private

  def estimate_time(tournaments)
    # Estimación basada en promedio de eventos por torneo y rate limits
    estimated_events = tournaments.sum { |t| [ t.events.count, 3 ].max } # Mínimo 3 eventos estimados
    estimated_minutes = (estimated_events * 8) / 60.0 # 8 segundos por evento promedio
    estimated_minutes.ceil
  end

  def percentage(part, total)
    return 0 if total == 0
    ((part.to_f / total) * 100).round(1)
  end
end
