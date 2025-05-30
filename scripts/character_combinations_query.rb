# Consultas para obtener combinaciones únicas de personaje y skin
# Ejecutar: ruby scripts/character_combinations_query.rb
# O en Rails console: load 'scripts/character_combinations_query.rb'

# Cargar entorno de Rails si no está cargado
unless defined?(Rails)
  require_relative '../config/environment'
end

require 'set'

# ========================================
# OPCIÓN 1: Combinaciones únicas de todos los slots (character_1, character_2, character_3)
# ========================================

puts "=== OPCIÓN 1: Todas las combinaciones únicas de personaje + skin ==="

# Obtener todas las combinaciones de character_1 + skin_1
combinations_1 = Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1).uniq

# Obtener todas las combinaciones de character_2 + skin_2  
combinations_2 = Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2).uniq

# Obtener todas las combinaciones de character_3 + skin_3
combinations_3 = Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3).uniq

# Combinar todas y eliminar duplicados
all_combinations = (combinations_1 + combinations_2 + combinations_3).uniq.sort

puts "Total de combinaciones únicas: #{all_combinations.count}"
puts "\nCombinaciones (personaje, skin):"
all_combinations.each do |character, skin|
  character_name = Player::SMASH_CHARACTERS[character] || character.humanize
  puts "- #{character_name} (#{character}) - Skin #{skin}"
end

# ========================================
# OPCIÓN 2: Solo combinaciones del personaje principal (character_1)
# ========================================

puts "\n\n=== OPCIÓN 2: Solo personajes principales (character_1) ==="

main_combinations = Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1).uniq.sort

puts "Total de combinaciones principales: #{main_combinations.count}"
puts "\nCombinaciones principales (personaje, skin):"
main_combinations.each do |character, skin|
  character_name = Player::SMASH_CHARACTERS[character] || character.humanize
  puts "- #{character_name} (#{character}) - Skin #{skin}"
end

# ========================================
# OPCIÓN 3: Agrupado por personaje con todas sus skins usadas
# ========================================

puts "\n\n=== OPCIÓN 3: Agrupado por personaje ==="

# Crear hash para agrupar por personaje
character_skins = {}

# Procesar character_1
Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1).each do |character, skin|
  character_skins[character] ||= Set.new
  character_skins[character] << skin
end

# Procesar character_2
Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2).each do |character, skin|
  character_skins[character] ||= Set.new
  character_skins[character] << skin
end

# Procesar character_3
Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3).each do |character, skin|
  character_skins[character] ||= Set.new
  character_skins[character] << skin
end

puts "Personajes y sus skins utilizadas:"
character_skins.sort.each do |character, skins|
  character_name = Player::SMASH_CHARACTERS[character] || character.humanize
  sorted_skins = skins.to_a.sort
  puts "- #{character_name} (#{character}): Skins #{sorted_skins.join(', ')}"
end

# ========================================
# OPCIÓN 4: Estadísticas detalladas
# ========================================

puts "\n\n=== OPCIÓN 4: Estadísticas detalladas ==="

total_players = Player.count
players_with_characters = Player.where("character_1 IS NOT NULL AND character_1 != ''").count
players_with_secondary = Player.where("character_2 IS NOT NULL AND character_2 != ''").count
players_with_tertiary = Player.where("character_3 IS NOT NULL AND character_3 != ''").count

puts "Total de jugadores: #{total_players}"
puts "Jugadores con personaje principal: #{players_with_characters}"
puts "Jugadores con personaje secundario: #{players_with_secondary}"
puts "Jugadores con personaje terciario: #{players_with_tertiary}"

# Personajes más populares
puts "\nPersonajes más populares (character_1):"
character_counts = Player.where.not(character_1: [nil, ""]).group(:character_1).count.sort_by { |k, v| -v }
character_counts.first(10).each do |character, count|
  character_name = Player::SMASH_CHARACTERS[character] || character.humanize
  puts "- #{character_name}: #{count} jugadores"
end

# ========================================
# OPCIÓN 5: Consulta SQL directa (más eficiente)
# ========================================

puts "\n\n=== OPCIÓN 5: Consulta SQL optimizada ==="

sql_query = <<~SQL
  SELECT DISTINCT character, skin, character_name
  FROM (
    SELECT character_1 as character, skin_1 as skin, 'character_1' as slot
    FROM players 
    WHERE character_1 IS NOT NULL AND character_1 != ''
    
    UNION ALL
    
    SELECT character_2 as character, skin_2 as skin, 'character_2' as slot
    FROM players 
    WHERE character_2 IS NOT NULL AND character_2 != ''
    
    UNION ALL
    
    SELECT character_3 as character, skin_3 as skin, 'character_3' as slot
    FROM players 
    WHERE character_3 IS NOT NULL AND character_3 != ''
  ) as all_characters
  LEFT JOIN (
    SELECT 'mario' as char_key, 'Mario' as character_name
    -- Aquí se podría expandir con todos los personajes
  ) as char_names ON all_characters.character = char_names.char_key
  ORDER BY character, skin;
SQL

results = ActiveRecord::Base.connection.execute(sql_query)
puts "Resultados de consulta SQL directa:"
results.each do |row|
  character = row['character']
  skin = row['skin']
  character_name = Player::SMASH_CHARACTERS[character] || character.humanize
  puts "- #{character_name} (#{character}) - Skin #{skin}"
end

puts "\n=== FIN DE CONSULTAS ===" 