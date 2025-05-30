#!/usr/bin/env ruby
# Script para probar la nueva funcionalidad de captura de entrants sin cuenta

require_relative '../config/environment'

puts "🧪 PRUEBA: Captura de entrants sin cuenta de start.gg"
puts "=" * 60

# Buscar un evento existente para probar
test_event = Event.joins(:tournament)
                  .where(tournaments: { name: "Torneo Redragon - Smash Ultimate en Open Arena" })
                  .first

if test_event.nil?
  puts "❌ No se encontró el evento de prueba. Usando el primer evento disponible..."
  test_event = Event.joins(:tournament).first
end

if test_event.nil?
  puts "❌ No hay eventos disponibles en la base de datos"
  exit 1
end

puts "🎯 Evento de prueba: #{test_event.name}"
puts "🏆 Torneo: #{test_event.tournament.name}"
puts "🆔 Event ID: #{test_event.id}"
puts "📊 Seeds actuales: #{test_event.calculated_event_seeds_count}"
puts "👥 Attendees count actual: #{test_event.attendees_count || 'No establecido'}"
puts ""

# Realizar sync de seeds con la nueva funcionalidad
puts "🔄 Iniciando sincronización con nueva funcionalidad..."
sync_service = SyncEventSeeds.new(test_event, force: true, update_players: false)

begin
  result = sync_service.call
  
  # Recargar el evento para obtener datos actualizados
  test_event.reload
  
  puts ""
  puts "✅ RESULTADOS DE LA SINCRONIZACIÓN:"
  puts "📊 Seeds después del sync: #{test_event.calculated_event_seeds_count}"
  puts "👥 Attendees count: #{test_event.attendees_count}"
  puts "🎯 Diferencia: #{test_event.attendees_seeds_difference}"
  puts "📈 Completitud: #{test_event.seeds_completeness_percentage}%"
  puts ""
  
  # Analizar tipos de jugadores creados
  seeds_with_account = test_event.event_seeds.joins(:player).where.not(players: { user_id: nil }).count
  seeds_without_account = test_event.event_seeds.joins(:player).where(players: { user_id: nil }).count
  
  puts "👤 ANÁLISIS DE JUGADORES:"
  puts "✅ Con cuenta de start.gg: #{seeds_with_account}"
  puts "❌ Sin cuenta de start.gg: #{seeds_without_account}"
  puts "📊 Total: #{seeds_with_account + seeds_without_account}"
  puts ""
  
  # Mostrar algunos ejemplos de jugadores sin cuenta
  players_without_account = Player.joins(:event_seeds)
                                  .where(event_seeds: { event: test_event })
                                  .where(user_id: nil)
                                  .limit(5)
  
  if players_without_account.any?
    puts "🔍 EJEMPLOS DE JUGADORES SIN CUENTA:"
    players_without_account.each do |player|
      seed = player.event_seeds.find_by(event: test_event)
      puts "   - #{player.entrant_name} (Seed: #{seed&.seed_num}, start_gg_id: #{player.start_gg_id})"
    end
    puts ""
  end
  
  if test_event.has_attendees_discrepancy?
    puts "⚠️ TODAVÍA HAY DISCREPANCIA:"
    puts "   Faltan #{test_event.attendees_seeds_difference.abs} entrants"
    puts "   Esto puede deberse a entrants duplicados o problemas en la API"
  else
    puts "🎉 ¡ÉXITO! Ya no hay discrepancia entre attendees y seeds"
  end
  
rescue StandardError => e
  puts "❌ ERROR durante la sincronización:"
  puts "   #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

puts ""
puts "🏁 Prueba completada" 