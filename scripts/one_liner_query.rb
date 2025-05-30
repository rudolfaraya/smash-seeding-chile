# Consultas rápidas de una línea para análisis exploratorio
# Ejecutar: ruby scripts/one_liner_query.rb
# O en Rails console: load 'scripts/one_liner_query.rb'

# Cargar entorno de Rails si no está cargado
unless defined?(Rails)
  require_relative '../config/environment'
end

# CONSULTAS DE UNA LÍNEA PARA RAILS CONSOLE
# Copia y pega cualquiera de estas líneas en rails console

# 1. Todas las combinaciones únicas (más simple)
(Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1) + Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2) + Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3)).uniq.sort.each { |char, skin| puts "#{Player::SMASH_CHARACTERS[char] || char.humanize} - Skin #{skin}" }

# 2. Solo personajes principales (character_1)
Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1).uniq.sort.each { |char, skin| puts "#{Player::SMASH_CHARACTERS[char] || char.humanize} - Skin #{skin}" }

# 3. Contar combinaciones únicas
puts (Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1) + Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2) + Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3)).uniq.count

# 4. Personajes más populares
Player.where.not(character_1: [nil, ""]).group(:character_1).count.sort_by { |k, v| -v }.first(10).each { |char, count| puts "#{Player::SMASH_CHARACTERS[char] || char.humanize}: #{count} jugadores" }

# 5. Obtener solo los nombres de personajes únicos (sin skins)
Player.where.not(character_1: [nil, ""]).distinct.pluck(:character_1).sort.each { |char| puts Player::SMASH_CHARACTERS[char] || char.humanize }

# 6. Combinaciones con información detallada
(Player.where.not(character_1: [nil, ""]).pluck(:character_1, :skin_1) + Player.where.not(character_2: [nil, ""]).pluck(:character_2, :skin_2) + Player.where.not(character_3: [nil, ""]).pluck(:character_3, :skin_3)).uniq.sort.each_with_index { |(char, skin), i| puts "#{i+1}. #{(Player::SMASH_CHARACTERS[char] || char.humanize).ljust(20)} - Skin #{skin}" } 