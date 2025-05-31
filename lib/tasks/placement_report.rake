# Método helper para calcular porcentajes
def percentage(part, total)
  return 0 if total == 0
  ((part.to_f / total) * 100).round(1)
end

namespace :placement do
  desc "Genera un resumen completo de placements faltantes en eventos"
  task report: :environment do
    puts "🎯 REPORTE DE PLACEMENTS - #{Time.current.strftime('%d/%m/%Y %H:%M')}"
    puts "=" * 70

    # Estadísticas generales
    total_seeds = EventSeed.count
    seeds_with_placement = EventSeed.where.not(placement: nil).count
    seeds_without_placement = total_seeds - seeds_with_placement

    puts "\n📊 ESTADÍSTICAS GENERALES:"
    puts "   Total EventSeeds: #{total_seeds}"
    puts "   Con placement: #{seeds_with_placement} (#{percentage(seeds_with_placement, total_seeds)}%)"
    puts "   Sin placement: #{seeds_without_placement} (#{percentage(seeds_without_placement, total_seeds)}%)"

    # Estadísticas por evento
    events_with_seeds = Event.joins(:event_seeds).distinct
    total_events = events_with_seeds.count
    events_complete = events_with_seeds.where.not(id: Event.joins(:event_seeds).where(event_seeds: { placement: nil }).distinct.pluck(:id)).count
    events_incomplete = total_events - events_complete

    puts "\n🎮 ESTADÍSTICAS POR EVENTO:"
    puts "   Total eventos con seeds: #{total_events}"
    puts "   Eventos completos (100% placements): #{events_complete} (#{percentage(events_complete, total_events)}%)"
    puts "   Eventos incompletos: #{events_incomplete} (#{percentage(events_incomplete, total_events)}%)"

    # Detalle de eventos incompletos
    if events_incomplete > 0
      puts "\n❌ EVENTOS CON PLACEMENTS FALTANTES:"
      puts "-" * 70

      Event.joins(:event_seeds, :tournament)
           .select("events.*, tournaments.name as tournament_name,
                    COUNT(event_seeds.id) as total_seeds,
                    COUNT(CASE WHEN event_seeds.placement IS NOT NULL THEN 1 END) as seeds_with_placement")
           .group("events.id, tournaments.name")
           .having("COUNT(CASE WHEN event_seeds.placement IS NULL THEN 1 END) > 0")
           .order("tournaments.start_at DESC, events.name")
           .each do |event|
        missing_count = event.total_seeds - event.seeds_with_placement
        completion_pct = percentage(event.seeds_with_placement, event.total_seeds)

        puts "#{event.tournament_name} - #{event.name}"
        puts "   Seeds: #{event.total_seeds} | Con placement: #{event.seeds_with_placement} | Faltantes: #{missing_count} (#{100-completion_pct}%)"
        puts "   ID: #{event.id} | start_gg_event_id: #{event.start_gg_event_id}"
        puts ""
      end
    end

    # Top eventos con más placements faltantes
    puts "\n🔝 TOP 10 EVENTOS CON MÁS PLACEMENTS FALTANTES:"
    puts "-" * 70

    Event.joins(:event_seeds, :tournament)
         .select("events.*, tournaments.name as tournament_name,
                  COUNT(event_seeds.id) as total_seeds,
                  COUNT(CASE WHEN event_seeds.placement IS NULL THEN 1 END) as missing_placements")
         .group("events.id, tournaments.name")
         .having("COUNT(CASE WHEN event_seeds.placement IS NULL THEN 1 END) > 0")
         .order("missing_placements DESC")
         .limit(10)
         .each_with_index do |event, index|
      puts "#{index + 1}. #{event.tournament_name} - #{event.name}"
      puts "    Faltantes: #{event.missing_placements}/#{event.total_seeds} seeds"
      puts "    Comando: rails runner \"SyncEventSeedsJob.perform_now(#{event.id})\""
      puts ""
    end

    # Eventos sin ningún placement
    events_zero_placements = Event.joins(:event_seeds)
                                  .where(event_seeds: { placement: nil })
                                  .where.not(id: Event.joins(:event_seeds).where.not(event_seeds: { placement: nil }).distinct.pluck(:id))
                                  .distinct

    if events_zero_placements.any?
      puts "\n🚨 EVENTOS SIN NINGÚN PLACEMENT (#{events_zero_placements.count}):"
      puts "-" * 70

      events_zero_placements.joins(:tournament)
                           .order("tournaments.start_at DESC")
                           .limit(15)
                           .each do |event|
        seeds_count = event.event_seeds.count
        puts "#{event.tournament.name} - #{event.name} (#{seeds_count} seeds)"
        puts "   ID: #{event.id} | Comando: rails runner \"SyncEventSeedsJob.perform_now(#{event.id})\""
      end

      if events_zero_placements.count > 15
        puts "   ... y #{events_zero_placements.count - 15} eventos más"
      end
    end

    puts "\n" + "=" * 70
    puts "✅ Reporte completado"
  end

  desc "Sincronizar placements para todos los eventos incompletos"
  task sync_missing: :environment do
    puts "🔄 SINCRONIZANDO PLACEMENTS FALTANTES..."
    puts "=" * 50

    events_with_missing = Event.joins(:event_seeds)
                               .where(event_seeds: { placement: nil })
                               .distinct
                               .joins(:tournament)
                               .order("tournaments.start_at DESC")

    total_events = events_with_missing.count
    puts "📊 Eventos a sincronizar: #{total_events}"

    return if total_events == 0

    puts "\n🚀 Iniciando sincronización..."

    events_with_missing.each_with_index do |event, index|
      puts "\n[#{index + 1}/#{total_events}] #{event.tournament.name} - #{event.name}"

      begin
        SyncEventSeedsJob.perform_now(event.id)
        puts "   ✅ Sincronizado exitosamente"
      rescue => e
        puts "   ❌ Error: #{e.message}"
      end

      # Rate limiting
      sleep(2) if index < total_events - 1
    end

    puts "\n✅ Sincronización completada"
  end

  desc "Sincronizar SOLO eventos que no tienen ningún placement en toda la historia"
  task sync_empty: :environment do
    puts "🚨 SINCRONIZANDO EVENTOS SIN NINGÚN PLACEMENT..."
    puts "=" * 60

    # Encontrar eventos que tienen seeds pero NINGÚN placement
    events_zero_placements = Event.joins(:event_seeds)
                                  .where(event_seeds: { placement: nil })
                                  .where.not(id: Event.joins(:event_seeds).where.not(event_seeds: { placement: nil }).distinct.pluck(:id))
                                  .distinct
                                  .joins(:tournament)
                                  .order("tournaments.start_at DESC")

    total_events = events_zero_placements.count
    puts "📊 Eventos completamente vacíos encontrados: #{total_events}"

    if total_events == 0
      puts "✅ ¡Todos los eventos ya tienen al menos algunos placements!"
      return
    end

    # Mostrar resumen antes de empezar
    puts "\n📋 RESUMEN DE EVENTOS A SINCRONIZAR:"
    puts "-" * 50

    total_seeds = 0
    events_zero_placements.each_with_index do |event, index|
      seeds_count = event.event_seeds.count
      total_seeds += seeds_count
      puts "#{index + 1}. #{event.tournament.name} - #{event.name} (#{seeds_count} seeds)"
    end

    puts "\n📊 Total seeds a procesar: #{total_seeds}"
    puts "⏱️ Tiempo estimado: #{(total_events * 2)} segundos (con rate limiting)"

    puts "\n🚀 Iniciando sincronización..."

    success_count = 0
    error_count = 0

    events_zero_placements.each_with_index do |event, index|
      puts "\n[#{index + 1}/#{total_events}] #{event.tournament.name} - #{event.name}"
      puts "   Seeds: #{event.event_seeds.count} | start_gg_event_id: #{event.start_gg_event_id}"

      begin
        # Verificar que el evento tiene start_gg_event_id
        unless event.start_gg_event_id
          puts "   ⚠️ Saltando: evento sin start_gg_event_id"
          next
        end

        SyncEventSeedsJob.perform_now(event.id)

        # Verificar resultado
        event.reload
        new_placements = event.event_seeds.where.not(placement: nil).count

        if new_placements > 0
          puts "   ✅ Sincronizado exitosamente: #{new_placements} placements obtenidos"
          success_count += 1
        else
          puts "   ⚠️ Sincronizado pero sin placements (evento posiblemente sin resultados)"
          success_count += 1
        end

      rescue => e
        puts "   ❌ Error: #{e.message.truncate(100)}"
        error_count += 1
      end

      # Rate limiting más agresivo para eventos históricos
      if index < total_events - 1
        puts "   ⏱️ Esperando 3 segundos..."
        sleep(3)
      end
    end

    puts "\n" + "=" * 60
    puts "✅ Sincronización de eventos vacíos completada"
    puts "📊 RESULTADO FINAL:"
    puts "   Exitosos: #{success_count}/#{total_events}"
    puts "   Errores: #{error_count}/#{total_events}"
    puts "   Éxito: #{percentage(success_count, total_events)}%"

    if error_count > 0
      puts "\n💡 TIP: Los errores suelen ser por eventos muy antiguos o sin resultados en start.gg"
    end
  end
end
