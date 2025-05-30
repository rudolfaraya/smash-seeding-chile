# Script para generar reporte de combinaciones de personajes en archivo de texto
# Ejecutar en Rails console: load 'scripts/generate_character_report.rb'
# O ejecutar directamente: ruby scripts/generate_character_report.rb

# Cargar entorno de Rails si no está cargado
unless defined?(Rails)
  require_relative '../config/environment'
end

puts "🎮 Generando reporte de combinaciones de personajes..."

# Nombre del archivo con timestamp (usar Time.now para compatibilidad)
time_method = defined?(Time.current) ? Time.current : Time.now
timestamp = time_method.strftime("%Y%m%d_%H%M%S")
filename = "character_combinations_report_#{timestamp}.txt"

# Abrir archivo para escritura
File.open(filename, 'w') do |file|
  # Encabezado del reporte
  file.puts "=" * 80
  file.puts "REPORTE DE COMBINACIONES DE PERSONAJES DE SMASH"
  file.puts "Generado el: #{time_method.strftime('%d/%m/%Y a las %H:%M:%S')}"
  file.puts "=" * 80
  file.puts

  # ========================================
  # SECCIÓN 1: Estadísticas generales
  # ========================================
  
  file.puts "📊 ESTADÍSTICAS GENERALES"
  file.puts "-" * 40
  
  total_players = Player.count
  players_with_characters = Player.where("character_1 IS NOT NULL AND character_1 != ''").count
  players_with_secondary = Player.where("character_2 IS NOT NULL AND character_2 != ''").count
  players_with_tertiary = Player.where("character_3 IS NOT NULL AND character_3 != ''").count
  
  file.puts "Total de jugadores registrados: #{total_players}"
  file.puts "Jugadores con personaje principal: #{players_with_characters}"
  file.puts "Jugadores con personaje secundario: #{players_with_secondary}"
  file.puts "Jugadores con personaje terciario: #{players_with_tertiary}"
  file.puts "Porcentaje con personajes: #{((players_with_characters.to_f / total_players) * 100).round(1)}%"
  file.puts

  # ========================================
  # SECCIÓN 2: Todas las combinaciones únicas
  # ========================================
  
  file.puts "🎯 TODAS LAS COMBINACIONES ÚNICAS (PERSONAJE + SKIN)"
  file.puts "-" * 60
  
  # Obtener todas las combinaciones
  combinations_1 = Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1).uniq
  combinations_2 = Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2).uniq
  combinations_3 = Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3).uniq
  
  all_combinations = (combinations_1 + combinations_2 + combinations_3).uniq.sort
  
  file.puts "Total de combinaciones únicas encontradas: #{all_combinations.count}"
  file.puts
  
  all_combinations.each_with_index do |(character, skin), index|
    character_name = Player::SMASH_CHARACTERS[character] || character.humanize
    file.puts "#{(index + 1).to_s.rjust(3)}. #{character_name.ljust(25)} - Skin #{skin}"
  end
  
  file.puts
  
  # ========================================
  # SECCIÓN 3: Agrupado por personaje
  # ========================================
  
  file.puts "📋 PERSONAJES Y SUS SKINS UTILIZADAS"
  file.puts "-" * 50
  
  character_skins = {}
  
  # Procesar todos los slots
  [
    Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1),
    Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2),
    Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3)
  ].flatten(1).each do |character, skin|
    character_skins[character] ||= Set.new
    character_skins[character] << skin
  end
  
  character_skins.sort.each do |character, skins|
    character_name = Player::SMASH_CHARACTERS[character] || character.humanize
    sorted_skins = skins.to_a.sort
    file.puts "#{character_name.ljust(25)} - Skins: #{sorted_skins.join(', ')}"
  end
  
  file.puts
  
  # ========================================
  # SECCIÓN 4: Personajes más populares
  # ========================================
  
  file.puts "🏆 TOP 15 PERSONAJES MÁS POPULARES (PERSONAJE PRINCIPAL)"
  file.puts "-" * 60
  
  character_counts = Player.where.not(character_1: [nil, ""]).group(:character_1).count.sort_by { |k, v| -v }
  character_counts.first(15).each_with_index do |(character, count), index|
    character_name = Player::SMASH_CHARACTERS[character] || character.humanize
    percentage = ((count.to_f / players_with_characters) * 100).round(1)
    file.puts "#{(index + 1).to_s.rjust(2)}. #{character_name.ljust(25)} - #{count.to_s.rjust(3)} jugadores (#{percentage}%)"
  end
  
  file.puts
  
  # ========================================
  # SECCIÓN 5: Análisis de skins
  # ========================================
  
  file.puts "🎨 ANÁLISIS DE SKINS MÁS UTILIZADAS"
  file.puts "-" * 45
  
  # Contar uso de skins por slot
  skin_usage = Hash.new(0)
  
  Player.where.not(character_1: [nil, ""]).pluck(:skin_1).each { |skin| skin_usage[skin] += 1 }
  Player.where.not(character_2: [nil, ""]).pluck(:skin_2).each { |skin| skin_usage[skin] += 1 }
  Player.where.not(character_3: [nil, ""]).pluck(:skin_3).each { |skin| skin_usage[skin] += 1 }
  
  file.puts "Distribución de skins utilizadas:"
  (1..8).each do |skin_num|
    count = skin_usage[skin_num]
    file.puts "Skin #{skin_num}: #{count.to_s.rjust(3)} usos"
  end
  
  file.puts
  
  # ========================================
  # SECCIÓN 6: Personajes sin usar
  # ========================================
  
  file.puts "❌ PERSONAJES NO UTILIZADOS"
  file.puts "-" * 35
  
  used_characters = character_skins.keys
  all_characters = Player::SMASH_CHARACTERS.keys
  unused_characters = all_characters - used_characters
  
  if unused_characters.any?
    file.puts "Personajes disponibles pero no utilizados por ningún jugador:"
    unused_characters.sort.each do |character|
      character_name = Player::SMASH_CHARACTERS[character] || character.humanize
      file.puts "- #{character_name}"
    end
  else
    file.puts "¡Todos los personajes están siendo utilizados por al menos un jugador!"
  end
  
  file.puts
  
  # ========================================
  # SECCIÓN 7: Resumen final
  # ========================================
  
  file.puts "📈 RESUMEN FINAL"
  file.puts "-" * 25
  file.puts "Total de personajes disponibles: #{Player::SMASH_CHARACTERS.count}"
  file.puts "Personajes utilizados: #{character_skins.count}"
  file.puts "Personajes no utilizados: #{unused_characters.count}"
  file.puts "Combinaciones únicas (personaje + skin): #{all_combinations.count}"
  file.puts "Cobertura de personajes: #{((character_skins.count.to_f / Player::SMASH_CHARACTERS.count) * 100).round(1)}%"
  
  file.puts
  file.puts "=" * 80
  file.puts "Fin del reporte - Generado por Smash Seeding Chile"
  file.puts "=" * 80
end

puts "✅ Reporte generado exitosamente: #{filename}"
puts "📁 Ubicación: #{File.expand_path(filename)}"
puts "📊 El archivo contiene:"
puts "   - Estadísticas generales"
puts "   - Todas las combinaciones únicas"
puts "   - Personajes agrupados con sus skins"
puts "   - Top 15 personajes más populares"
puts "   - Análisis de skins"
puts "   - Personajes no utilizados"
puts "   - Resumen final"
puts
puts "🎮 ¡Listo para revisar!" 