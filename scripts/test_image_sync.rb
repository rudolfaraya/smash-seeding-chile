#!/usr/bin/env ruby

# Script para probar la sincronización de imágenes desde start.gg
require_relative '../config/environment'

puts "🧪 Script de prueba para sincronización de imágenes"
puts "=" * 60

# Verificar cliente de start.gg
begin
  client = StartGgClient.new
  puts "✅ Cliente de start.gg inicializado correctamente"
rescue StandardError => e
  puts "❌ Error inicializando cliente: #{e.message}"
  exit 1
end

# Buscar un torneo de ejemplo
tournament = Tournament.where.not(slug: nil).first
if tournament.nil?
  puts "❌ No se encontraron torneos con slug en la base de datos"
  exit 1
end

puts "🏆 Torneo de prueba: #{tournament.name} (#{tournament.slug})"

# Probar consulta de imágenes de torneo
puts "\n🔍 Probando consulta de imágenes de torneo..."
begin
  images = StartGgQueries.fetch_tournament_images(client, tournament.slug)
  puts "✅ Consulta exitosa. Imágenes encontradas: #{images.length}"

  if images.any?
    image = images.first
    puts "   📸 Primera imagen:"
    puts "      URL: #{image['url']}"
    puts "      Dimensiones: #{image['width']}x#{image['height']}"
    puts "      Ratio: #{image['ratio']}"
    puts "      Tipo: #{image['type']}"
  end
rescue StandardError => e
  puts "❌ Error en consulta de imágenes: #{e.message}"
end

# Probar sincronización de imagen de torneo
puts "\n🔄 Probando sincronización de imagen de torneo..."
begin
  original_url = tournament.banner_image_url
  result = tournament.sync_banner_image_from_start_gg!

  if result
    puts "✅ Sincronización exitosa"
    puts "   URL anterior: #{original_url || 'ninguna'}"
    puts "   URL nueva: #{tournament.banner_image_url}"
    puts "   Dimensiones: #{tournament.banner_image_dimensions}"
  else
    puts "⚪ Sin imágenes disponibles para sincronizar"
  end
rescue StandardError => e
  puts "❌ Error sincronizando imagen: #{e.message}"
end

# Buscar un evento con start_gg_event_id de ejemplo
event = Event.where.not(start_gg_event_id: nil).first
if event.nil?
  puts "\n⚠️ No se encontraron eventos con start_gg_event_id"
else
  puts "\n🎯 Evento de prueba: #{event.tournament.name} - #{event.name} (ID: #{event.start_gg_event_id})"

  # Probar consulta de imágenes de evento
  puts "\n🔍 Probando consulta de imágenes de evento..."
  begin
    images = StartGgQueries.fetch_event_images(client, event.start_gg_event_id.to_s)
    puts "✅ Consulta exitosa. Imágenes encontradas: #{images.length}"

    if images.any?
      image = images.first
      puts "   📸 Primera imagen:"
      puts "      URL: #{image['url']}"
      puts "      Dimensiones: #{image['width']}x#{image['height']}"
      puts "      Ratio: #{image['ratio']}"
      puts "      Tipo: #{image['type']}"
    end
  rescue StandardError => e
    puts "❌ Error en consulta de imágenes: #{e.message}"
  end

  # Probar sincronización de imagen de evento
  puts "\n🔄 Probando sincronización de imagen de evento..."
  begin
    original_url = event.profile_image_url
    result = event.sync_profile_image_from_start_gg!

    if result
      puts "✅ Sincronización exitosa"
      puts "   URL anterior: #{original_url || 'ninguna'}"
      puts "   URL nueva: #{event.profile_image_url}"
      puts "   Dimensiones: #{event.profile_image_dimensions}"
    else
      puts "⚪ Sin imágenes disponibles para sincronizar"
    end
  rescue StandardError => e
    puts "❌ Error sincronizando imagen: #{e.message}"
  end
end

# Mostrar estadísticas actuales
puts "\n📊 Estadísticas actuales de imágenes:"
tournaments_with_images = Tournament.where.not(banner_image_url: nil).count
total_tournaments = Tournament.count
events_with_images = Event.where.not(profile_image_url: nil).count
total_events = Event.count

puts "   🏆 Torneos con imagen: #{tournaments_with_images}/#{total_tournaments}"
puts "   🎯 Eventos con imagen: #{events_with_images}/#{total_events}"

puts "\n✅ Script de prueba completado"
