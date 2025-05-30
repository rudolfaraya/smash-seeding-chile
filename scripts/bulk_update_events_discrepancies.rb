#!/usr/bin/env ruby
# Script para actualizar masivamente eventos con discrepancias entre attendees y seeds

require_relative '../config/environment'

puts "🔧 ACTUALIZACIÓN MASIVA: Eventos con discrepancias de attendees"
puts "=" * 70

# Configuración
FORCE_UPDATE = true # Forzar actualización incluso si ya hay seeds
UPDATE_PLAYERS = false # No actualizar información de jugadores existentes
MIN_DISCREPANCY = 5 # Mínima discrepancia para considerar actualización
MIN_COMPLETENESS = 95.0 # Mínimo porcentaje de completitud para saltar

# Estadísticas iniciales
puts "📊 ANÁLISIS INICIAL"
puts "-" * 40

# Encontrar eventos con discrepancias significativas
events_with_discrepancies = Event.joins(:tournament)
                                 .where.not(events: { attendees_count: nil })
                                 .where('events.attendees_count > 0')
                                 .includes(:event_seeds, :tournament)
                                 .select do |event|
  discrepancy = event.attendees_seeds_difference.abs
  completeness = event.seeds_completeness_percentage
  
  discrepancy >= MIN_DISCREPANCY && completeness < MIN_COMPLETENESS
end

total_events = events_with_discrepancies.length
puts "🎯 Eventos con discrepancias significativas: #{total_events}"

if total_events == 0
  puts "✅ ¡No hay eventos que requieran actualización!"
  exit 0
end

# Mostrar resumen de eventos a procesar
puts "\n📋 EVENTOS A PROCESAR:"
puts "-" * 40
events_with_discrepancies.each_with_index do |event, index|
  puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
  puts "   📊 Seeds: #{event.calculated_event_seeds_count}, Attendees: #{event.attendees_count}"
  puts "   📈 Completitud: #{event.seeds_completeness_percentage}%"
  puts "   🎯 Diferencia: #{event.attendees_seeds_difference}"
  puts ""
end

# Confirmación del usuario
puts "⚠️  ADVERTENCIA: Este proceso:"
puts "   - Eliminará y recreará seeds para #{total_events} eventos"
puts "   - Puede tardar varios minutos"
puts "   - Realizará muchas llamadas a la API de start.gg"
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
  improvements: [],
  errors: []
}

puts "\n🚀 INICIANDO ACTUALIZACIÓN MASIVA"
puts "=" * 70

# Procesar cada evento
events_with_discrepancies.each_with_index do |event, index|
  current_event = index + 1
  
  puts "\n📍 EVENTO #{current_event}/#{total_events}"
  puts "🏆 Torneo: #{event.tournament.name}"
  puts "🎯 Evento: #{event.name}"
  puts "🆔 ID: #{event.id}"
  
  # Estadísticas antes de la actualización
  seeds_before = event.calculated_event_seeds_count
  attendees_before = event.attendees_count
  completeness_before = event.seeds_completeness_percentage
  
  puts "📊 ANTES: #{seeds_before} seeds de #{attendees_before} attendees (#{completeness_before}%)"
  
  begin
    # Realizar la sincronización
    puts "🔄 Iniciando sincronización..."
    sync_service = SyncEventSeeds.new(event, force: FORCE_UPDATE, update_players: UPDATE_PLAYERS)
    sync_service.call
    
    # Recargar evento para obtener datos actualizados
    event.reload
    
    # Estadísticas después de la actualización
    seeds_after = event.calculated_event_seeds_count
    attendees_after = event.attendees_count
    completeness_after = event.seeds_completeness_percentage
    difference_after = event.attendees_seeds_difference
    
    # Calcular mejora
    improvement = seeds_after - seeds_before
    completeness_improvement = completeness_after - completeness_before
    
    puts "📊 DESPUÉS: #{seeds_after} seeds de #{attendees_after} attendees (#{completeness_after}%)"
    
    if improvement > 0
      puts "🎉 MEJORA: +#{improvement} seeds (#{completeness_improvement.round(1)}% más completo)"
      
      # Analizar tipos de jugadores
      seeds_with_account = event.event_seeds.joins(:player).where.not(players: { user_id: nil }).count
      seeds_without_account = event.event_seeds.joins(:player).where(players: { user_id: nil }).count
      
      puts "👤 Con cuenta: #{seeds_with_account}, Sin cuenta: #{seeds_without_account}"
      
      if difference_after.abs > 0
        puts "⚠️  Diferencia restante: #{difference_after}"
      else
        puts "✅ ¡Sin discrepancias!"
      end
      
      stats[:improvements] << {
        event: event,
        improvement: improvement,
        completeness_improvement: completeness_improvement,
        seeds_before: seeds_before,
        seeds_after: seeds_after,
        with_account: seeds_with_account,
        without_account: seeds_without_account
      }
    else
      puts "😕 Sin mejoras detectadas"
    end
    
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
    puts "⏱️  Esperando 3 segundos antes del siguiente evento..."
    sleep 3
  end
end

puts "\n" + "=" * 70
puts "🏁 ACTUALIZACIÓN MASIVA COMPLETADA"
puts "=" * 70

# Resumen final
puts "\n📊 ESTADÍSTICAS FINALES:"
puts "✅ Eventos procesados: #{stats[:processed]}"
puts "🎉 Exitosos: #{stats[:successful]}"
puts "❌ Fallidos: #{stats[:failed]}"
puts "🚀 Con mejoras: #{stats[:improvements].length}"

if stats[:improvements].any?
  puts "\n🎯 RESUMEN DE MEJORAS:"
  puts "-" * 40
  
  total_seeds_added = 0
  total_without_account = 0
  
  stats[:improvements].each_with_index do |improvement, index|
    event = improvement[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   📈 #{improvement[:seeds_before]} → #{improvement[:seeds_after]} seeds (+#{improvement[:improvement]})"
    puts "   📊 Completitud: #{improvement[:completeness_improvement].round(1)}% más"
    puts "   👤 Sin cuenta capturados: #{improvement[:without_account]}"
    puts ""
    
    total_seeds_added += improvement[:improvement]
    total_without_account += improvement[:without_account]
  end
  
  puts "🎉 TOTALES:"
  puts "   🚀 Seeds agregados: #{total_seeds_added}"
  puts "   👤 Jugadores sin cuenta capturados: #{total_without_account}"
  
  # Calcular mejora promedio
  avg_improvement = (total_seeds_added.to_f / stats[:improvements].length).round(1)
  puts "   📊 Mejora promedio por evento: #{avg_improvement} seeds"
end

if stats[:errors].any?
  puts "\n❌ EVENTOS CON ERRORES:"
  puts "-" * 40
  stats[:errors].each_with_index do |error, index|
    event = error[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   Error: #{error[:error]}"
    puts ""
  end
end

# Estadísticas globales finales
puts "\n🌟 IMPACTO GLOBAL:"
puts "-" * 40

# Recalcular estadísticas después de todas las actualizaciones
events_still_with_discrepancies = Event.joins(:tournament)
                                       .where.not(events: { attendees_count: nil })
                                       .where('events.attendees_count > 0')
                                       .includes(:event_seeds)
                                       .count { |e| e.attendees_seeds_difference.abs >= MIN_DISCREPANCY }

puts "📉 Eventos con discrepancias significativas restantes: #{events_still_with_discrepancies}"

# Completitud promedio mejorada
all_events_with_attendees = Event.where.not(events: { attendees_count: nil }).where('events.attendees_count > 0')
avg_completeness = all_events_with_attendees.map(&:seeds_completeness_percentage).sum.to_f / all_events_with_attendees.count

puts "📊 Completitud promedio del sistema: #{avg_completeness.round(1)}%"

puts "\n✨ ¡Actualización masiva completada!" 