#!/usr/bin/env ruby
# Script para analizar en detalle las discrepancias entre attendees_count y seeds

require_relative '../config/environment'

puts "🔍 ANÁLISIS DETALLADO: Discrepancias entre attendees y seeds"
puts "=" * 70

# Configuración
SAMPLE_SIZE = 5 # Número de eventos a analizar en detalle

# Encontrar eventos con discrepancias más significativas
events_with_discrepancies = Event.joins(:tournament)
                                 .where.not(events: { attendees_count: nil })
                                 .where('events.attendees_count > 0')
                                 .includes(:event_seeds, :tournament)
                                 .select { |event| event.attendees_seeds_difference != 0 }
                                 .sort_by { |event| -event.attendees_seeds_difference.abs }

puts "📊 RESUMEN GENERAL:"
puts "🎯 Total eventos con attendees_count: #{Event.where.not(attendees_count: nil).where('attendees_count > 0').count}"
puts "⚠️  Eventos con discrepancias: #{events_with_discrepancies.length}"
puts "🔥 Discrepancia máxima: #{events_with_discrepancies.first&.attendees_seeds_difference&.abs || 0}"

# Categorizar discrepancias
discrepancy_ranges = {
  'Muy alta (>50)' => events_with_discrepancies.select { |e| e.attendees_seeds_difference.abs > 50 },
  'Alta (21-50)' => events_with_discrepancies.select { |e| e.attendees_seeds_difference.abs.between?(21, 50) },
  'Media (11-20)' => events_with_discrepancies.select { |e| e.attendees_seeds_difference.abs.between?(11, 20) },
  'Baja (1-10)' => events_with_discrepancies.select { |e| e.attendees_seeds_difference.abs.between?(1, 10) }
}

puts "\n📈 DISTRIBUCIÓN DE DISCREPANCIAS:"
discrepancy_ranges.each do |range, events|
  puts "#{range}: #{events.length} eventos"
end

# Seleccionar eventos para análisis detallado
sample_events = events_with_discrepancies.first(SAMPLE_SIZE)

puts "\n🔬 ANÁLISIS DETALLADO DE #{SAMPLE_SIZE} EVENTOS:"
puts "=" * 70

sample_events.each_with_index do |event, index|
  puts "\n📍 EVENTO #{index + 1}/#{SAMPLE_SIZE}"
  puts "🏆 Torneo: #{event.tournament.name}"
  puts "🎯 Evento: #{event.name}"
  puts "🆔 ID: #{event.id}"
  puts "📊 Seeds actuales: #{event.calculated_event_seeds_count}"
  puts "👥 Attendees según API: #{event.attendees_count}"
  puts "🎯 Diferencia: #{event.attendees_seeds_difference}"
  puts "📈 Completitud: #{event.seeds_completeness_percentage}%"
  
  begin
    puts "\n🔍 INVESTIGANDO ENTRANTS EN LA API..."
    
    # Realizar consulta directa a la API para investigar
    client = StartGgClient.new
    all_api_entrants = []
    page = 1
    
    loop do
      variables = {
        eventId: event.id,
        perPage: 100,
        page: page
      }
      
      response = client.query(StartGgQueries::EVENT_ALL_ENTRANTS_QUERY, variables, "EventAllEntrants")
      
      unless response&.dig("data", "event")
        puts "❌ No se pudo obtener datos del evento desde la API"
        break
      end
      
      event_data = response["data"]["event"]
      entrants = event_data.dig("entrants", "nodes") || []
      
      if entrants.empty?
        break
      end
      
      all_api_entrants.concat(entrants)
      
      page_info = event_data.dig("entrants", "pageInfo")
      total_pages = page_info&.dig("totalPages") || 1
      
      break if page >= total_pages
      page += 1
    end
    
    # Analizar los entrants obtenidos
    puts "📡 Entrants obtenidos de la API: #{all_api_entrants.length}"
    
    # Categorizar entrants
    entrants_with_seed = all_api_entrants.select { |e| e["initialSeedNum"] }
    entrants_without_seed = all_api_entrants.reject { |e| e["initialSeedNum"] }
    entrants_with_user = all_api_entrants.select { |e| e.dig("participants", 0, "player", "user") }
    entrants_without_user = all_api_entrants.reject { |e| e.dig("participants", 0, "player", "user") }
    
    puts "📊 CATEGORIZACIÓN DE ENTRANTS:"
    puts "  ✅ Con initialSeedNum: #{entrants_with_seed.length}"
    puts "  ❌ Sin initialSeedNum: #{entrants_without_seed.length}"
    puts "  👤 Con cuenta de usuario: #{entrants_with_user.length}"
    puts "  🚫 Sin cuenta de usuario: #{entrants_without_user.length}"
    
    # Verificar duplicados
    entrant_ids = all_api_entrants.map { |e| e["id"] }
    duplicated_ids = entrant_ids.select { |id| entrant_ids.count(id) > 1 }.uniq
    
    if duplicated_ids.any?
      puts "⚠️  ENTRANTS DUPLICADOS DETECTADOS:"
      duplicated_ids.each do |id|
        duplicates = all_api_entrants.select { |e| e["id"] == id }
        puts "    ID #{id}: #{duplicates.first["name"]} (aparece #{duplicates.length} veces)"
      end
    else
      puts "✅ No se detectaron entrants duplicados"
    end
    
    # Mostrar ejemplos de entrants problemáticos
    if entrants_without_seed.any?
      puts "\n🔍 EJEMPLOS DE ENTRANTS SIN SEED:"
      entrants_without_seed.first(3).each do |entrant|
        player_name = entrant["name"]
        has_user = entrant.dig("participants", 0, "player", "user") ? "Con cuenta" : "Sin cuenta"
        puts "  - #{player_name} (#{has_user})"
      end
    end
    
    # Analizar seeds duplicados
    seeds = entrants_with_seed.map { |e| e["initialSeedNum"] }
    duplicated_seeds = seeds.select { |seed| seeds.count(seed) > 1 }.uniq
    
    if duplicated_seeds.any?
      puts "\n⚠️  SEEDS DUPLICADOS DETECTADOS:"
      duplicated_seeds.each do |seed_num|
        duplicates = entrants_with_seed.select { |e| e["initialSeedNum"] == seed_num }
        puts "    Seed #{seed_num}:"
        duplicates.each do |entrant|
          puts "      - #{entrant["name"]}"
        end
      end
    end
    
    # Posibles explicaciones para la discrepancia
    missing_entrants = event.attendees_count - all_api_entrants.length
    
    puts "\n🧮 ANÁLISIS DE DISCREPANCIA:"
    puts "  📊 Attendees según numEntrants: #{event.attendees_count}"
    puts "  📡 Entrants obtenidos via API: #{all_api_entrants.length}"
    puts "  🎯 Entrants faltantes en API: #{missing_entrants}"
    puts "  ❌ Entrants sin seed: #{entrants_without_seed.length}"
    puts "  🔄 Total explicado: #{missing_entrants + entrants_without_seed.length}"
    
    if missing_entrants > 0
      puts "\n💡 POSIBLES CAUSAS DE ENTRANTS FALTANTES:"
      puts "  - Jugadores que se retiraron (DQ'd)"
      puts "  - Entrants de staff que no compiten"
      puts "  - Limitaciones de paginación de la API"
      puts "  - Inconsistencias en los datos de start.gg"
    end
    
  rescue StandardError => e
    puts "❌ ERROR analizando evento: #{e.message}"
  end
  
  puts "\n" + "-" * 50
  
  # Pausa entre análisis
  if index < SAMPLE_SIZE - 1
    sleep 2
  end
end

# Análisis estadístico general
puts "\n📊 ESTADÍSTICAS GENERALES:"
puts "=" * 40

total_seeds = events_with_discrepancies.sum(&:calculated_event_seeds_count)
total_attendees = events_with_discrepancies.sum(&:attendees_count)
total_difference = total_attendees - total_seeds

puts "🎯 Seeds totales capturados: #{total_seeds}"
puts "👥 Attendees totales según API: #{total_attendees}"
puts "🔥 Diferencia total: #{total_difference}"
puts "📈 Completitud promedio: #{((total_seeds.to_f / total_attendees) * 100).round(1)}%"

# Distribución de completitud
completeness_ranges = {
  'Excelente (95-100%)' => 0,
  'Buena (80-94%)' => 0,
  'Regular (60-79%)' => 0,
  'Mala (40-59%)' => 0,
  'Muy mala (<40%)' => 0
}

events_with_discrepancies.each do |event|
  completeness = event.seeds_completeness_percentage
  case completeness
  when 95..100
    completeness_ranges['Excelente (95-100%)'] += 1
  when 80..94
    completeness_ranges['Buena (80-94%)'] += 1
  when 60..79
    completeness_ranges['Regular (60-79%)'] += 1
  when 40..59
    completeness_ranges['Mala (40-59%)'] += 1
  else
    completeness_ranges['Muy mala (<40%)'] += 1
  end
end

puts "\n📈 DISTRIBUCIÓN DE COMPLETITUD:"
completeness_ranges.each do |range, count|
  percentage = (count.to_f / events_with_discrepancies.length * 100).round(1)
  puts "#{range}: #{count} eventos (#{percentage}%)"
end

puts "\n💡 RECOMENDACIONES:"
puts "=" * 40
puts "1. 🎯 Ejecutar actualización masiva para eventos con completitud < 95%"
puts "2. 🔍 Investigar eventos con discrepancias muy altas (>50)"
puts "3. 📊 Monitorear eventos donde falten entrants sin seed"
puts "4. 🔄 Considerar mejoras en la paginación de la API"
puts "5. ⚠️  Reportar seeds duplicados a start.gg si es necesario"

puts "\n✨ ¡Análisis completado!" 