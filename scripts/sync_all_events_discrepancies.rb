#!/usr/bin/env ruby
# Script para sincronizar todos los eventos con posibles discrepancias

require_relative '../config/environment'

puts "🔄 SINCRONIZACIÓN COMPLETA: Eventos con discrepancias"
puts "=" * 70

# Configuración
FORCE_UPDATE = true # Forzar actualización incluso si ya hay seeds
UPDATE_PLAYERS = false # No actualizar información de jugadores existentes
MIN_DISCREPANCY = 1 # Mínima discrepancia para considerar problemático
BATCH_SIZE = 10 # Procesar en lotes para evitar sobrecargar la API

puts "📊 ANÁLISIS INICIAL"
puts "-" * 40

# 1. Eventos que ya tienen attendees_count pero con discrepancias
events_with_known_discrepancies = Event.joins(:tournament)
                                       .where.not(events: { attendees_count: nil })
                                       .where('events.attendees_count > 0')
                                       .includes(:event_seeds, :tournament)
                                       .select { |event| event.attendees_seeds_difference.abs >= MIN_DISCREPANCY }

# 2. Eventos sin attendees_count que podrían tener discrepancias (eventos válidos de Smash)
events_without_attendees_count = Event.joins(:tournament)
                                     .where(events: { attendees_count: nil })
                                     .where(events: { videogame_id: Event::SMASH_ULTIMATE_VIDEOGAME_ID })
                                     .where('events.team_max_players IS NULL OR events.team_max_players <= 1')
                                     .includes(:event_seeds, :tournament)
                                     .where.not(events: { id: nil })

# 3. Eventos sin seeds que definitivamente necesitan sincronización
events_without_seeds = Event.joins(:tournament)
                           .left_joins(:event_seeds)
                           .where(events: { videogame_id: Event::SMASH_ULTIMATE_VIDEOGAME_ID })
                           .where('events.team_max_players IS NULL OR events.team_max_players <= 1')
                           .where(event_seeds: { id: nil })
                           .includes(:tournament)
                           .distinct

puts "📈 CATEGORÍAS DE EVENTOS:"
puts "🔍 Con attendees_count y discrepancias: #{events_with_known_discrepancies.length}"
puts "❓ Sin attendees_count establecido: #{events_without_attendees_count.length}"
puts "🚫 Sin seeds (nunca sincronizados): #{events_without_seeds.length}"

# Combinar y eliminar duplicados
all_events_to_sync = (events_with_known_discrepancies + 
                     events_without_attendees_count + 
                     events_without_seeds).uniq(&:id)

total_events = all_events_to_sync.length
puts "🎯 Total eventos a sincronizar: #{total_events}"

if total_events == 0
  puts "✅ ¡No hay eventos que requieran sincronización!"
  exit 0
end

# Mostrar resumen por categoría
puts "\n📋 RESUMEN DE EVENTOS A SINCRONIZAR:"
puts "-" * 50

if events_with_known_discrepancies.any?
  puts "\n🔍 EVENTOS CON DISCREPANCIAS CONOCIDAS (#{events_with_known_discrepancies.length}):"
  events_with_known_discrepancies.first(5).each_with_index do |event, index|
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   📊 Seeds: #{event.calculated_event_seeds_count}, Attendees: #{event.attendees_count}"
    puts "   🎯 Diferencia: #{event.attendees_seeds_difference}"
  end
  puts "   ... y #{[events_with_known_discrepancies.length - 5, 0].max} más" if events_with_known_discrepancies.length > 5
end

if events_without_attendees_count.any?
  puts "\n❓ EVENTOS SIN ATTENDEES_COUNT (#{events_without_attendees_count.length}):"
  events_without_attendees_count.first(3).each_with_index do |event, index|
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   📊 Seeds actuales: #{event.calculated_event_seeds_count}"
  end
  puts "   ... y #{[events_without_attendees_count.length - 3, 0].max} más" if events_without_attendees_count.length > 3
end

if events_without_seeds.any?
  puts "\n🚫 EVENTOS SIN SEEDS (#{events_without_seeds.length}):"
  events_without_seeds.first(3).each_with_index do |event, index|
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   📊 Seeds: 0 (nunca sincronizado)"
  end
  puts "   ... y #{[events_without_seeds.length - 3, 0].max} más" if events_without_seeds.length > 3
end

# Confirmación del usuario
puts "\n⚠️  ADVERTENCIA: Este proceso:"
puts "   - Sincronizará #{total_events} eventos"
puts "   - Puede tardar 30+ minutos"
puts "   - Realizará cientos de llamadas a la API de start.gg"
puts "   - Recreará seeds para eventos existentes"
puts ""
print "¿Continuar? (y/N): "
confirmation = STDIN.gets.chomp.downcase

unless ['y', 'yes', 'sí', 'si'].include?(confirmation)
  puts "❌ Operación cancelada por el usuario"
  exit 0
end

# Inicializar estadísticas
stats = {
  processed: 0,
  successful: 0,
  failed: 0,
  new_events_synced: 0,
  improvements: [],
  errors: [],
  total_seeds_before: 0,
  total_seeds_after: 0,
  total_attendees: 0
}

puts "\n🚀 INICIANDO SINCRONIZACIÓN COMPLETA"
puts "=" * 70

# Procesar eventos en lotes
all_events_to_sync.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
  batch_start = batch_index * BATCH_SIZE + 1
  batch_end = [batch_start + batch.length - 1, total_events].min
  
  puts "\n🎯 LOTE #{batch_index + 1} (Eventos #{batch_start}-#{batch_end} de #{total_events})"
  puts "=" * 50
  
  batch.each_with_index do |event, index|
    current_event = batch_start + index
    
    puts "\n📍 EVENTO #{current_event}/#{total_events}"
    puts "🏆 Torneo: #{event.tournament.name}"
    puts "🎯 Evento: #{event.name}"
    puts "🆔 ID: #{event.id}"
    
    # Estadísticas antes de la sincronización
    seeds_before = event.calculated_event_seeds_count
    attendees_before = event.attendees_count || 0
    completeness_before = attendees_before > 0 ? event.seeds_completeness_percentage : 0
    
    puts "📊 ANTES: #{seeds_before} seeds"
    if attendees_before > 0
      puts "👥 Attendees conocidos: #{attendees_before} (#{completeness_before}% completitud)"
    else
      puts "👥 Attendees: No establecido"
    end
    
    begin
      # Realizar la sincronización
      puts "🔄 Iniciando sincronización..."
      sync_service = SyncEventSeeds.new(event, force: FORCE_UPDATE, update_players: UPDATE_PLAYERS)
      sync_service.call
      
      # Recargar evento para obtener datos actualizados
      event.reload
      
      # Estadísticas después de la sincronización
      seeds_after = event.calculated_event_seeds_count
      attendees_after = event.attendees_count || 0
      completeness_after = attendees_after > 0 ? event.seeds_completeness_percentage : 0
      difference_after = attendees_after > 0 ? event.attendees_seeds_difference : 0
      
      # Calcular mejora
      seeds_improvement = seeds_after - seeds_before
      completeness_improvement = completeness_after - completeness_before
      
      puts "📊 DESPUÉS: #{seeds_after} seeds"
      if attendees_after > 0
        puts "👥 Attendees: #{attendees_after} (#{completeness_after}% completitud)"
        puts "🎯 Diferencia restante: #{difference_after}"
      else
        puts "👥 Attendees: No pudo determinarse desde la API"
      end
      
      # Determinar tipo de mejora
      if seeds_before == 0 && seeds_after > 0
        puts "🎉 NUEVO EVENTO SINCRONIZADO: #{seeds_after} seeds capturados"
        stats[:new_events_synced] += 1
      elsif seeds_improvement > 0
        puts "🚀 MEJORA: +#{seeds_improvement} seeds (#{completeness_improvement.round(1)}% más completo)"
      elsif seeds_improvement == 0 && seeds_after > 0
        puts "✅ CONFIRMADO: Seeds ya estaban actualizados"
      else
        puts "😕 Sin cambios detectados"
      end
      
      # Analizar tipos de jugadores si hay seeds
      if seeds_after > 0
        seeds_with_account = event.event_seeds.joins(:player).where.not(players: { user_id: nil }).count
        seeds_without_account = event.event_seeds.joins(:player).where(players: { user_id: nil }).count
        puts "👤 Con cuenta: #{seeds_with_account}, Sin cuenta: #{seeds_without_account}"
      end
      
      # Guardar estadísticas
      if seeds_improvement > 0 || (seeds_before == 0 && seeds_after > 0)
        stats[:improvements] << {
          event: event,
          seeds_improvement: seeds_improvement,
          completeness_improvement: completeness_improvement,
          seeds_before: seeds_before,
          seeds_after: seeds_after,
          attendees_after: attendees_after,
          was_new: seeds_before == 0
        }
      end
      
      stats[:total_seeds_before] += seeds_before
      stats[:total_seeds_after] += seeds_after
      stats[:total_attendees] += attendees_after
      stats[:successful] += 1
      
    rescue StandardError => e
      puts "❌ ERROR: #{e.message}"
      puts "🔍 #{e.backtrace.first(2).join(', ')}"
      
      stats[:errors] << {
        event: event,
        error: e.message
      }
      stats[:failed] += 1
    end
    
    stats[:processed] += 1
    
    # Pausa entre eventos para evitar rate limits
    if current_event < total_events
      puts "⏱️  Esperando 3 segundos..."
      sleep 3
    end
  end
  
  # Pausa más larga entre lotes
  if batch_index < (all_events_to_sync.length.to_f / BATCH_SIZE).ceil - 1
    puts "\n⏸️  PAUSA ENTRE LOTES: Esperando 10 segundos para evitar rate limits..."
    sleep 10
  end
end

puts "\n" + "=" * 70
puts "🏁 SINCRONIZACIÓN COMPLETA FINALIZADA"
puts "=" * 70

# Resumen final detallado
puts "\n📊 ESTADÍSTICAS FINALES:"
puts "✅ Eventos procesados: #{stats[:processed]}"
puts "🎉 Exitosos: #{stats[:successful]}"
puts "❌ Fallidos: #{stats[:failed]}"
puts "🆕 Nuevos eventos sincronizados: #{stats[:new_events_synced]}"
puts "🚀 Eventos con mejoras: #{stats[:improvements].length}"

# Estadísticas de seeds
puts "\n🎯 IMPACTO EN SEEDS:"
puts "📈 Seeds antes: #{stats[:total_seeds_before]}"
puts "📊 Seeds después: #{stats[:total_seeds_after]}"
puts "🚀 Seeds agregados: #{stats[:total_seeds_after] - stats[:total_seeds_before]}"

if stats[:total_attendees] > 0
  overall_completeness = (stats[:total_seeds_after].to_f / stats[:total_attendees] * 100).round(1)
  puts "👥 Total attendees: #{stats[:total_attendees]}"
  puts "📈 Completitud general: #{overall_completeness}%"
end

if stats[:improvements].any?
  puts "\n🎯 RESUMEN DE MEJORAS:"
  puts "-" * 40
  
  new_events = stats[:improvements].select { |i| i[:was_new] }
  improved_events = stats[:improvements].reject { |i| i[:was_new] }
  
  if new_events.any?
    puts "\n🆕 NUEVOS EVENTOS SINCRONIZADOS (#{new_events.length}):"
    new_events.each_with_index do |improvement, index|
      event = improvement[:event]
      puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
      puts "   📊 #{improvement[:seeds_after]} seeds capturados"
      puts "   👥 #{improvement[:attendees_after]} attendees"
    end
  end
  
  if improved_events.any?
    puts "\n🚀 EVENTOS MEJORADOS (#{improved_events.length}):"
    improved_events.each_with_index do |improvement, index|
      event = improvement[:event]
      puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
      puts "   📈 #{improvement[:seeds_before]} → #{improvement[:seeds_after]} seeds (+#{improvement[:seeds_improvement]})"
      puts "   📊 Completitud: #{improvement[:completeness_improvement].round(1)}% más"
    end
  end
  
  total_new_seeds = stats[:improvements].sum { |i| i[:seeds_improvement] }
  puts "\n🎉 TOTAL SEEDS AGREGADOS: #{total_new_seeds}"
end

if stats[:errors].any?
  puts "\n❌ EVENTOS CON ERRORES:"
  puts "-" * 40
  stats[:errors].each_with_index do |error, index|
    event = error[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   Error: #{error[:error]}"
  end
end

# Recomendaciones finales
puts "\n💡 PRÓXIMOS PASOS:"
puts "-" * 40
remaining_discrepancies = Event.joins(:tournament)
                              .where.not(events: { attendees_count: nil })
                              .where('events.attendees_count > 0')
                              .includes(:event_seeds)
                              .count { |e| e.attendees_seeds_difference.abs >= MIN_DISCREPANCY }

puts "1. 📊 Eventos con discrepancias restantes: #{remaining_discrepancies}"
puts "2. 🔍 Ejecutar análisis detallado si quedan discrepancias altas"
puts "3. 📈 Monitorear la completitud general del sistema"
puts "4. 🔄 Considerar sincronización periódica de eventos nuevos"

puts "\n✨ ¡Sincronización completa terminada!" 