#!/usr/bin/env ruby
# Script para sincronizar SOLO eventos sin seeds (nunca sincronizados)
# Ejecutar: ruby scripts/sync_events_without_seeds.rb

# Cargar entorno de Rails
unless defined?(Rails)
  require_relative '../config/environment'
end

puts "🚫 SINCRONIZACIÓN: Eventos sin seeds (nunca sincronizados)"
puts "=" * 65

# Configuración
FORCE_UPDATE = true
UPDATE_PLAYERS = false
BATCH_SIZE = 5 # Lotes más pequeños para eventos nuevos

puts "📊 ANÁLISIS INICIAL"
puts "-" * 40

# Solo eventos sin seeds que definitivamente necesitan sincronización
events_without_seeds = Event.joins(:tournament)
                           .left_joins(:event_seeds)
                           .where(events: { videogame_id: Event::SMASH_ULTIMATE_VIDEOGAME_ID })
                           .where('events.team_max_players IS NULL OR events.team_max_players <= 1')
                           .where(event_seeds: { id: nil })
                           .includes(:tournament)
                           .distinct

total_events = events_without_seeds.length
puts "🎯 Eventos sin seeds encontrados: #{total_events}"

if total_events == 0
  puts "✅ ¡Todos los eventos ya tienen seeds!"
  exit 0
end

# Mostrar algunos ejemplos
puts "\n📋 EJEMPLOS DE EVENTOS A SINCRONIZAR:"
puts "-" * 45
events_without_seeds.first(10).each_with_index do |event, index|
  puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
  puts "   🗓️  #{event.tournament.start_at&.strftime('%Y-%m-%d') || 'Sin fecha'}"
end
puts "   ... y #{[total_events - 10, 0].max} más" if total_events > 10

# Estimación de tiempo
estimated_minutes = (total_events * 4) / 60.0 # ~4 segundos por evento
puts "\n⏱️  ESTIMACIÓN:"
puts "   - Tiempo aproximado: #{estimated_minutes.round(1)} minutos"
puts "   - Llamadas a la API: ~#{total_events * 2}"
puts "   - Procesamiento en lotes de #{BATCH_SIZE}"

puts "\n¿Continuar? (y/N): "
confirmation = STDIN.gets.chomp.downcase

unless ['y', 'yes', 'sí', 'si'].include?(confirmation)
  puts "❌ Operación cancelada por el usuario"
  exit 0
end

# Estadísticas
stats = {
  processed: 0,
  successful: 0,
  failed: 0,
  events_synced: 0,
  total_seeds_captured: 0,
  total_attendees: 0,
  errors: [],
  synced_events: []
}

puts "\n🚀 INICIANDO SINCRONIZACIÓN DE EVENTOS SIN SEEDS"
puts "=" * 65

start_time = Time.now

# Procesar en lotes
events_without_seeds.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
  batch_start = batch_index * BATCH_SIZE + 1
  batch_end = [batch_start + batch.length - 1, total_events].min
  
  puts "\n🎯 LOTE #{batch_index + 1} (Eventos #{batch_start}-#{batch_end} de #{total_events})"
  puts "=" * 40
  
  batch.each_with_index do |event, index|
    current_event = batch_start + index
    
    puts "\n📍 EVENTO #{current_event}/#{total_events}"
    puts "🏆 #{event.tournament.name}"
    puts "🎯 #{event.name}"
    puts "🆔 ID: #{event.id}"
    puts "🗓️  #{event.tournament.start_at&.strftime('%Y-%m-%d') || 'Sin fecha'}"
    
    begin
      puts "🔄 Sincronizando..."
      sync_service = SyncEventSeeds.new(event, force: FORCE_UPDATE, update_players: UPDATE_PLAYERS)
      sync_service.call
      
      # Recargar y analizar resultados
      event.reload
      seeds_captured = event.calculated_event_seeds_count
      attendees_count = event.attendees_count || 0
      
      if seeds_captured > 0
        puts "🎉 ÉXITO: #{seeds_captured} seeds capturados"
        if attendees_count > 0
          completeness = event.seeds_completeness_percentage
          puts "👥 Attendees: #{attendees_count} (#{completeness}% completitud)"
          
          # Analizar tipos de jugadores
          seeds_with_account = event.event_seeds.joins(:player).where.not(players: { user_id: nil }).count
          seeds_without_account = event.event_seeds.joins(:player).where(players: { user_id: nil }).count
          puts "👤 Con cuenta: #{seeds_with_account}, Sin cuenta: #{seeds_without_account}"
        else
          puts "👥 Attendees: No determinado desde la API"
        end
        
        stats[:events_synced] += 1
        stats[:total_seeds_captured] += seeds_captured
        stats[:total_attendees] += attendees_count
        stats[:synced_events] << {
          event: event,
          seeds: seeds_captured,
          attendees: attendees_count,
          with_account: seeds_with_account || 0,
          without_account: seeds_without_account || 0
        }
      else
        puts "😕 Sin seeds capturados (evento posiblemente vacío o inválido)"
      end
      
      stats[:successful] += 1
      
    rescue StandardError => e
      puts "❌ ERROR: #{e.message}"
      stats[:errors] << {
        event: event,
        error: e.message
      }
      stats[:failed] += 1
    end
    
    stats[:processed] += 1
    
    # Pausa entre eventos
    if current_event < total_events
      puts "⏱️  Esperando 4 segundos..."
      sleep 4
    end
  end
  
  # Pausa entre lotes
  if batch_index < (events_without_seeds.length.to_f / BATCH_SIZE).ceil - 1
    puts "\n⏸️  PAUSA ENTRE LOTES: 8 segundos..."
    sleep 8
  end
end

end_time = Time.now
duration = ((end_time - start_time) / 60.0).round(1)

puts "\n" + "=" * 65
puts "🏁 SINCRONIZACIÓN DE EVENTOS SIN SEEDS COMPLETADA"
puts "=" * 65

puts "\n📊 ESTADÍSTICAS FINALES:"
puts "✅ Eventos procesados: #{stats[:processed]}"
puts "🎉 Exitosos: #{stats[:successful]}"
puts "❌ Fallidos: #{stats[:failed]}"
puts "🆕 Eventos sincronizados: #{stats[:events_synced]}"
puts "🎯 Total seeds capturados: #{stats[:total_seeds_captured]}"
puts "👥 Total attendees: #{stats[:total_attendees]}"
puts "⏱️  Tiempo total: #{duration} minutos"

if stats[:total_attendees] > 0 && stats[:total_seeds_captured] > 0
  overall_completeness = (stats[:total_seeds_captured].to_f / stats[:total_attendees] * 100).round(1)
  puts "📈 Completitud promedio: #{overall_completeness}%"
end

if stats[:synced_events].any?
  puts "\n🎯 TOP 10 EVENTOS SINCRONIZADOS:"
  puts "-" * 40
  top_events = stats[:synced_events].sort_by { |e| -e[:seeds] }.first(10)
  
  top_events.each_with_index do |event_data, index|
    event = event_data[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   📊 #{event_data[:seeds]} seeds (#{event_data[:attendees]} attendees)"
    if event_data[:without_account] > 0
      puts "   👤 #{event_data[:with_account]} con cuenta, #{event_data[:without_account]} sin cuenta"
    end
  end
  
  # Estadísticas de jugadores sin cuenta
  total_without_account = stats[:synced_events].sum { |e| e[:without_account] }
  total_with_account = stats[:synced_events].sum { |e| e[:with_account] }
  
  if total_without_account > 0
    puts "\n👤 IMPACTO EN JUGADORES SIN CUENTA:"
    puts "✅ Con cuenta capturados: #{total_with_account}"
    puts "🆕 Sin cuenta capturados: #{total_without_account}"
    puts "📊 Total jugadores: #{total_with_account + total_without_account}"
    percentage_without = (total_without_account.to_f / (total_with_account + total_without_account) * 100).round(1)
    puts "📈 Porcentaje sin cuenta: #{percentage_without}%"
  end
end

if stats[:errors].any?
  puts "\n❌ EVENTOS CON ERRORES (#{stats[:errors].length}):"
  puts "-" * 40
  stats[:errors].first(5).each_with_index do |error, index|
    event = error[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   Error: #{error[:error]}"
  end
  puts "   ... y #{[stats[:errors].length - 5, 0].max} más" if stats[:errors].length > 5
end

puts "\n💡 RECOMENDACIONES:"
puts "1. 🔍 Ejecutar análisis de discrepancias en eventos recién sincronizados"
puts "2. 📊 Revisar eventos que no capturaron seeds"
puts "3. 🔄 Considerar sincronización de eventos con attendees_count faltante"

puts "\n✨ ¡Sincronización de eventos nuevos completada!" 