# Script simple para exportar combinaciones de personajes
# Ejecutar: ruby scripts/simple_combinations_export.rb

# Cargar entorno de Rails si no está cargado
unless defined?(Rails)
  require_relative '../config/environment'
end

require 'csv'

# Usar Time.now para compatibilidad
time_method = defined?(Time.current) ? Time.current : Time.now
timestamp = time_method.strftime("%Y%m%d_%H%M%S")
filename = "simple_combinations_#{timestamp}.csv"

puts "📊 Exportando combinaciones simples de personajes..."

# Obtener jugadores con personajes
players_with_characters = Player.where.not(character_1: [nil, ""])
                                .includes(:user)

CSV.open(filename, "wb") do |csv|
  # Encabezados
  csv << ["ID", "Jugador", "Personaje Principal", "Skin Principal", "Personaje Secundario", "Skin Secundario", "Eventos"]
  
  # Datos de jugadores
  players_with_characters.each do |player|
    char1_name = player.character_1 ? (Player::SMASH_CHARACTERS[player.character_1] || player.character_1.humanize) : ""
    char2_name = player.character_2 ? (Player::SMASH_CHARACTERS[player.character_2] || player.character_2.humanize) : ""
    
    csv << [
      player.id,
      player.entrant_name,
      char1_name,
      player.skin_1 || "",
      char2_name,
      player.skin_2 || "",
      player.events_count || 0
    ]
  end
end

# Crear archivo README descriptivo
readme_filename = "README_#{filename}.txt"
File.open(readme_filename, 'w') do |file|
  file.puts "Archivo: #{filename}"
  file.puts "Generado: #{time_method.strftime('%d/%m/%Y %H:%M:%S')}"
  file.puts "Descripción: Combinaciones de personajes principales y secundarios de jugadores"
  file.puts ""
  file.puts "Columnas:"
  file.puts "- ID: ID único del jugador"
  file.puts "- Jugador: Nombre del jugador (entrant_name)"
  file.puts "- Personaje Principal: Personaje principal utilizado"
  file.puts "- Skin Principal: Skin del personaje principal (1-8)"
  file.puts "- Personaje Secundario: Personaje secundario (si existe)"
  file.puts "- Skin Secundario: Skin del personaje secundario (si existe)"
  file.puts "- Eventos: Número de eventos en los que ha participado"
  file.puts ""
  file.puts "Total de jugadores exportados: #{players_with_characters.count}"
end

puts "✅ Archivo CSV generado: #{filename}"
puts "📊 Total de jugadores: #{players_with_characters.count}"
puts "📁 Ubicación: #{File.expand_path(filename)}"
puts "📄 README creado: #{readme_filename}"
puts "💡 Puedes abrir el CSV en Excel o Google Sheets" 