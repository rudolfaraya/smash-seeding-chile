#!/usr/bin/env ruby
# Script para sincronizar eventos sin attendees_count establecido
# Ejecutar: ruby scripts/sync_events_without_attendees.rb

# Cargar entorno de Rails
unless defined?(Rails)
  require_relative '../config/environment'
end

puts "❓ SINCRONIZACIÓN: Eventos sin attendees_count"
puts "=" * 55

# Configuración
FORCE_UPDATE = false # No forzar si ya hay seeds, solo obtener attendees_count
UPDATE_PLAYERS = false
BATCH_SIZE = 10 # Lotes medianos para esta operación
MAX_EVENTS = 100 # Limitar a los primeros 100 para no sobrecargar

puts "📊 ANÁLISIS INICIAL"
puts "-" * 40

# Eventos sin attendees_count establecido
events_without_attendees = Event.joins(:tournament)
                               .where(events: { attendees_count: nil })
                               .where(events: { videogame_id: Event::SMASH_ULTIMATE_VIDEOGAME_ID })
                               .where('events.team_max_players IS NULL OR events.team_max_players <= 1')
                               .includes(:event_seeds, :tournament)
                               .order('tournaments.start_at DESC') # Más recientes primero
                               .limit(MAX_EVENTS)

total_events = events_without_attendees.length
puts "🎯 Eventos sin attendees_count: #{total_events} (limitado a #{MAX_EVENTS})"

if total_events == 0
  puts "✅ ¡Todos los eventos ya tienen attendees_count!"
  exit 0
end

# Analizar cuántos ya tienen seeds
events_with_seeds = events_without_attendees.select { |e| e.calculated_event_seeds_count > 0 }
events_without_seeds = events_without_attendees.select { |e| e.calculated_event_seeds_count == 0 }

puts "\n📋 CATEGORÍAS:"
puts "✅ Con seeds existentes: #{events_with_seeds.length} (solo actualizar attendees_count)"
puts "🚫 Sin seeds: #{events_without_seeds.length} (sincronización completa)"

# Mostrar algunos ejemplos
puts "\n📋 EJEMPLOS DE EVENTOS:"
puts "-" * 30
events_without_attendees.first(8).each_with_index do |event, index|
  seeds_count = event.calculated_event_seeds_count
  status = seeds_count > 0 ? "#{seeds_count} seeds" : "sin seeds"
  puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
  puts "   📊 Estado: #{status}"
  puts "   🗓️  #{event.tournament.start_at&.strftime('%Y-%m-%d') || 'Sin fecha'}"
end
puts "   ... y #{[total_events - 8, 0].max} más" if total_events > 8

# Estimación de tiempo
estimated_minutes = (total_events * 3) / 60.0 # ~3 segundos por evento
puts "\n⏱️  ESTIMACIÓN:"
puts "   - Tiempo aproximado: #{estimated_minutes.round(1)} minutos"
puts "   - Limitado a #{MAX_EVENTS} eventos más recientes"
puts "   - Enfoque en obtener attendees_count faltante"

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
  attendees_count_added: 0,
  new_seeds_events: 0,
  improved_seeds_events: 0,
  total_attendees_found: 0,
  total_new_seeds: 0,
  errors: [],
  results: []
}

puts "\n🚀 INICIANDO SINCRONIZACIÓN DE ATTENDEES_COUNT"
puts "=" * 55

start_time = Time.now

# Procesar en lotes
events_without_attendees.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
  batch_start = batch_index * BATCH_SIZE + 1
  batch_end = [batch_start + batch.length - 1, total_events].min
  
  puts "\n🎯 LOTE #{batch_index + 1} (Eventos #{batch_start}-#{batch_end} de #{total_events})"
  puts "=" * 35
  
  batch.each_with_index do |event, index|
    current_event = batch_start + index
    
    puts "\n📍 EVENTO #{current_event}/#{total_events}"
    puts "🏆 #{event.tournament.name}"
    puts "🎯 #{event.name}"
    puts "🆔 ID: #{event.id}"
    
    # Estado antes
    seeds_before = event.calculated_event_seeds_count
    attendees_before = event.attendees_count
    
    puts "📊 ANTES: #{seeds_before} seeds, attendees: #{attendees_before || 'no establecido'}"
    
    begin
      puts "🔄 Obteniendo attendees_count..."
      
      # Determinar estrategia según estado actual
      if seeds_before > 0
        puts "   → Evento con seeds existentes: solo actualizar attendees_count"
        force_update = false
      else
        puts "   → Evento sin seeds: sincronización completa"
        force_update = true
      end
      
      sync_service = SyncEventSeeds.new(event, force: force_update, update_players: UPDATE_PLAYERS)
      sync_service.call
      
      # Recargar y analizar resultados
      event.reload
      seeds_after = event.calculated_event_seeds_count
      attendees_after = event.attendees_count
      
      # Resultados
      puts "📊 DESPUÉS: #{seeds_after} seeds, attendees: #{attendees_after || 'no determinado'}"
      
      # Analizar mejoras
      result_type = nil
      if attendees_after && !attendees_before
        puts "✅ ATTENDEES_COUNT OBTENIDO: #{attendees_after}"
        stats[:attendees_count_added] += 1
        stats[:total_attendees_found] += attendees_after
        result_type = 'attendees_added'
        
        if attendees_after > 0
          completeness = event.seeds_completeness_percentage
          puts "📈 Completitud: #{completeness}%"
          
          if completeness < 90
            puts "⚠️  Baja completitud: posible mejora de seeds necesaria"
          end
        end
      end
      
      if seeds_after > seeds_before
        seeds_improvement = seeds_after - seeds_before
        puts "🚀 SEEDS MEJORADOS: +#{seeds_improvement} seeds"
        stats[:total_new_seeds] += seeds_improvement
        
        if seeds_before == 0
          stats[:new_seeds_events] += 1
          result_type = 'new_seeds'
        else
          stats[:improved_seeds_events] += 1
          result_type = 'improved_seeds'
        end
        
        # Analizar tipos de jugadores
        if seeds_after > 0
          seeds_with_account = event.event_seeds.joins(:player).where.not(players: { user_id: nil }).count
          seeds_without_account = event.event_seeds.joins(:player).where(players: { user_id: nil }).count
          puts "👤 Con cuenta: #{seeds_with_account}, Sin cuenta: #{seeds_without_account}"
        end
      end
      
      stats[:results] << {
        event: event,
        type: result_type,
        seeds_before: seeds_before,
        seeds_after: seeds_after,
        attendees_before: attendees_before,
        attendees_after: attendees_after,
        improvement: seeds_after - seeds_before
      }
      
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
      puts "⏱️  Esperando 3 segundos..."
      sleep 3
    end
  end
  
  # Pausa entre lotes
  if batch_index < (events_without_attendees.length.to_f / BATCH_SIZE).ceil - 1
    puts "\n⏸️  PAUSA ENTRE LOTES: 6 segundos..."
    sleep 6
  end
end

end_time = Time.now
duration = ((end_time - start_time) / 60.0).round(1)

puts "\n" + "=" * 55
puts "🏁 SINCRONIZACIÓN DE ATTENDEES_COUNT COMPLETADA"
puts "=" * 55

puts "\n📊 ESTADÍSTICAS FINALES:"
puts "✅ Eventos procesados: #{stats[:processed]}"
puts "🎉 Exitosos: #{stats[:successful]}"
puts "❌ Fallidos: #{stats[:failed]}"
puts "👥 Attendees_count obtenidos: #{stats[:attendees_count_added]}"
puts "🆕 Eventos con nuevos seeds: #{stats[:new_seeds_events]}"
puts "🚀 Eventos con seeds mejorados: #{stats[:improved_seeds_events]}"
puts "🎯 Total nuevos seeds: #{stats[:total_new_seeds]}"
puts "👥 Total attendees encontrados: #{stats[:total_attendees_found]}"
puts "⏱️  Tiempo total: #{duration} minutos"

# Resumen por categorías
attendees_results = stats[:results].select { |r| r[:type] == 'attendees_added' }
new_seeds_results = stats[:results].select { |r| r[:type] == 'new_seeds' }
improved_seeds_results = stats[:results].select { |r| r[:type] == 'improved_seeds' }

if attendees_results.any?
  puts "\n👥 ATTENDEES_COUNT OBTENIDOS (#{attendees_results.length}):"
  puts "-" * 40
  attendees_results.first(10).each_with_index do |result, index|
    event = result[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   👥 #{result[:attendees_after]} attendees"
    if result[:seeds_after] > 0
      completeness = (result[:seeds_after].to_f / result[:attendees_after] * 100).round(1)
      puts "   📈 #{completeness}% completitud (#{result[:seeds_after]} seeds)"
    end
  end
  puts "   ... y #{[attendees_results.length - 10, 0].max} más" if attendees_results.length > 10
end

if new_seeds_results.any?
  puts "\n🆕 NUEVOS EVENTOS SINCRONIZADOS (#{new_seeds_results.length}):"
  puts "-" * 40
  new_seeds_results.first(5).each_with_index do |result, index|
    event = result[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   📊 #{result[:seeds_after]} seeds capturados"
    puts "   👥 #{result[:attendees_after]} attendees"
  end
  puts "   ... y #{[new_seeds_results.length - 5, 0].max} más" if new_seeds_results.length > 5
end

if improved_seeds_results.any?
  puts "\n🚀 SEEDS MEJORADOS (#{improved_seeds_results.length}):"
  puts "-" * 40
  improved_seeds_results.first(5).each_with_index do |result, index|
    event = result[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   📈 #{result[:seeds_before]} → #{result[:seeds_after]} seeds (+#{result[:improvement]})"
    if result[:attendees_after]
      completeness = (result[:seeds_after].to_f / result[:attendees_after] * 100).round(1)
      puts "   📊 #{completeness}% completitud"
    end
  end
  puts "   ... y #{[improved_seeds_results.length - 5, 0].max} más" if improved_seeds_results.length > 5
end

if stats[:errors].any?
  puts "\n❌ EVENTOS CON ERRORES (#{stats[:errors].length}):"
  puts "-" * 40
  stats[:errors].first(3).each_with_index do |error, index|
    event = error[:event]
    puts "#{index + 1}. #{event.tournament.name} - #{event.name}"
    puts "   Error: #{error[:error]}"
  end
  puts "   ... y #{[stats[:errors].length - 3, 0].max} más" if stats[:errors].length > 3
end

# Estadísticas de completitud
if stats[:total_attendees_found] > 0 && stats[:total_new_seeds] > 0
  overall_completeness = (stats[:total_new_seeds].to_f / stats[:total_attendees_found] * 100).round(1)
  puts "\n📈 COMPLETITUD GENERAL DE NUEVOS EVENTOS: #{overall_completeness}%"
end

puts "\n💡 PRÓXIMOS PASOS:"
puts "1. 🔍 Revisar eventos con baja completitud (<90%)"
puts "2. 📊 Analizar eventos que no pudieron obtener attendees_count"
puts "3. 🔄 Considerar sincronización de eventos restantes (#{Event.where(attendees_count: nil).count - total_events} más)"

puts "\n✨ ¡Sincronización de attendees_count completada!" 