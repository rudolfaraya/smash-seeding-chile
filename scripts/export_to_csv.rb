# Script para exportar combinaciones de personajes a CSV
# Ejecutar: ruby scripts/export_to_csv.rb

# Cargar entorno de Rails si no está cargado
unless defined?(Rails)
  require_relative '../config/environment'
end

require 'csv'

puts "📊 Exportando combinaciones de personajes a CSV..."

# Usar Time.now para compatibilidad
time_method = defined?(Time.current) ? Time.current : Time.now
timestamp = time_method.strftime("%Y%m%d_%H%M%S")

# Nombre del archivo
csv_filename = "character_combinations_#{timestamp}.csv"

# Obtener todas las combinaciones únicas
combinations_1 = Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1).uniq
combinations_2 = Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2).uniq
combinations_3 = Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3).uniq

all_combinations = (combinations_1 + combinations_2 + combinations_3).uniq.sort

# Generar CSV
CSV.open(csv_filename, 'w', write_headers: true, headers: ['ID', 'Character_Key', 'Character_Name', 'Skin', 'Full_Name']) do |csv|
  all_combinations.each_with_index do |(character, skin), index|
    character_name = Player::SMASH_CHARACTERS[character] || character.humanize
    full_name = "#{character_name} - Skin #{skin}"
    
    csv << [
      index + 1,
      character,
      character_name,
      skin,
      full_name
    ]
  end
end

puts "✅ Archivo CSV generado: #{csv_filename}"
puts "📊 Total de combinaciones: #{all_combinations.count}"
puts "📁 Ubicación: #{File.expand_path(csv_filename)}"
puts "💡 Puedes abrir este archivo en Excel o Google Sheets"

# También generar estadísticas en CSV separado
stats_filename = "character_stats_#{timestamp}.csv"

CSV.open(stats_filename, 'w', write_headers: true, headers: ['Character_Key', 'Character_Name', 'Total_Players', 'Skins_Used', 'Percentage']) do |csv|
  # Obtener estadísticas por personaje
  character_counts = Player.where.not(character_1: [nil, ""]).group(:character_1).count
  total_players_with_chars = Player.where("character_1 IS NOT NULL AND character_1 != ''").count
  
  # Obtener skins por personaje
  character_skins = {}
  [
    Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1),
    Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2),
    Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3)
  ].flatten(1).each do |character, skin|
    character_skins[character] ||= Set.new
    character_skins[character] << skin
  end
  
  character_counts.sort_by { |k, v| -v }.each do |character, count|
    character_name = Player::SMASH_CHARACTERS[character] || character.humanize
    skins_used = character_skins[character]&.size || 0
    percentage = ((count.to_f / total_players_with_chars) * 100).round(2)
    
    csv << [
      character,
      character_name,
      count,
      skins_used,
      percentage
    ]
  end
end

puts "✅ Archivo de estadísticas generado: #{stats_filename}"
puts "🎮 ¡Archivos listos para análisis!" 