# Consulta simple de personajes más utilizados
# Ejecutar: ruby scripts/simple_character_query.rb
# O en Rails console: load 'scripts/simple_character_query.rb'

# Cargar entorno de Rails si no está cargado
unless defined?(Rails)
  require_relative '../config/environment'
end

puts "🎮 Obteniendo todas las combinaciones únicas de personaje + skin..."

# Método para obtener todas las combinaciones
def get_all_character_combinations
  combinations = []
  
  # Obtener de character_1
  Player.where.not(character_1: [nil, ""]).find_each do |player|
    combinations << [player.character_1, player.skin_1 || 1]
  end
  
  # Obtener de character_2
  Player.where.not(character_2: [nil, ""]).find_each do |player|
    combinations << [player.character_2, player.skin_2 || 1]
  end
  
  # Obtener de character_3
  Player.where.not(character_3: [nil, ""]).find_each do |player|
    combinations << [player.character_3, player.skin_3 || 1]
  end
  
  # Eliminar duplicados y ordenar
  combinations.uniq.sort
end

# Ejecutar la consulta
all_combinations = get_all_character_combinations

puts "\n📊 RESULTADOS:"
puts "Total de combinaciones únicas: #{all_combinations.count}"
puts "\n📋 Lista de combinaciones (Personaje - Skin):"
puts "=" * 50

all_combinations.each_with_index do |(character, skin), index|
  character_name = Player::SMASH_CHARACTERS[character] || character.humanize
  puts "#{(index + 1).to_s.rjust(3)}. #{character_name.ljust(20)} - Skin #{skin}"
end

puts "\n" + "=" * 50
puts "✅ Consulta completada"

# También crear un hash agrupado por personaje
puts "\n🎯 AGRUPADO POR PERSONAJE:"
puts "=" * 50

character_groups = {}
all_combinations.each do |character, skin|
  character_groups[character] ||= []
  character_groups[character] << skin
end

character_groups.sort.each do |character, skins|
  character_name = Player::SMASH_CHARACTERS[character] || character.humanize
  puts "#{character_name.ljust(20)} - Skins: #{skins.sort.join(', ')}"
end

puts "\n" + "=" * 50
puts "🏁 Análisis completado" 