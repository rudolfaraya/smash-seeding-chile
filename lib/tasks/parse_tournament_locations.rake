namespace :tournaments do
  desc "Parsea y actualiza la ciudad y región de todos los torneos basándose en venue_address"
  task parse_locations: :environment do
    puts "🏛️  Iniciando parseo de ubicaciones de torneos..."
    
    begin
      service = LocationParserService.new
      updated_count = service.parse_all_tournaments
      
      puts "✅ Proceso completado. #{updated_count} torneos actualizados."
      
      # Mostrar estadísticas
      total_tournaments = Tournament.count
      tournaments_with_city = Tournament.where.not(city: [nil, '']).count
      tournaments_with_region = Tournament.where.not(region: [nil, '']).count
      online_tournaments = Tournament.online_tournaments.count
      
      puts "\n📊 Estadísticas:"
      puts "   Total de torneos: #{total_tournaments}"
      puts "   Torneos con ciudad: #{tournaments_with_city} (#{((tournaments_with_city.to_f / total_tournaments) * 100).round(1)}%)"
      puts "   Torneos con región: #{tournaments_with_region} (#{((tournaments_with_region.to_f / total_tournaments) * 100).round(1)}%)"
      puts "   🌐 Torneos online: #{online_tournaments} (#{((online_tournaments.to_f / total_tournaments) * 100).round(1)}%)"
      
      # Mostrar regiones encontradas
      regions = Tournament.where.not(region: [nil, '']).distinct.pluck(:region).sort
      puts "\n🗺️  Regiones identificadas:"
      regions.each do |region|
        count = Tournament.where(region: region).count
        emoji = region == 'Online' ? '🌐' : '📍'
        puts "   #{emoji} #{region}: #{count} torneos"
      end
      
    rescue => e
      puts "❌ Error durante el parseo: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Identifica y marca torneos online basándose en nombre y venue_address"
  task detect_online_tournaments: :environment do
    puts "🌐 DETECTANDO TORNEOS ONLINE"
    puts "=" * 50
    
    begin
      service = LocationParserService.new
      updated_count = service.identify_online_tournaments_by_name_and_venue
      
      puts "✅ Proceso completado. #{updated_count} torneos marcados como online."
      
      # Mostrar estadísticas
      total_online = Tournament.online_tournaments.count
      total_tournaments = Tournament.count
      
      puts "\n📊 Estadísticas de torneos online:"
      puts "   🌐 Total torneos online: #{total_online}"
      puts "   📊 Porcentaje del total: #{((total_online.to_f / total_tournaments) * 100).round(1)}%"
      
      # Mostrar algunos ejemplos de torneos online detectados
      puts "\n🎮 Ejemplos de torneos online detectados:"
      Tournament.online_tournaments.limit(10).each_with_index do |tournament, index|
        puts "   #{index + 1}. #{tournament.name}"
        puts "      📅 #{tournament.start_at&.strftime('%d/%m/%Y')}"
        puts "      🏟️  #{tournament.venue_address || 'Sin venue_address'}"
        puts ""
      end
      
    rescue => e
      puts "❌ Error durante la detección: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Revisa torneos que podrían ser online pero no están marcados"
  task check_potential_online: :environment do
    puts "🔍 REVISANDO TORNEOS QUE PODRÍAN SER ONLINE"
    puts "=" * 50
    
    potential_online = []
    
    Tournament.physical_tournaments.each do |tournament|
      if tournament.should_be_online?
        potential_online << tournament
      end
    end
    
    if potential_online.any?
      puts "⚠️  Encontrados #{potential_online.count} torneos que podrían ser online:"
      puts ""
      
      potential_online.each_with_index do |tournament, index|
        puts "#{index + 1}. 🏆 #{tournament.name}"
        puts "   📅 #{tournament.start_at&.strftime('%d/%m/%Y')}"
        puts "   🏟️  #{tournament.venue_address || 'Sin venue_address'}"
        puts "   🗺️  Región actual: #{tournament.region || 'Sin región'}"
        puts ""
      end
      
      puts "💡 Para marcar estos torneos como online, ejecuta:"
      puts "   bin/rails tournaments:detect_online_tournaments"
    else
      puts "✅ No se encontraron torneos que deberían estar marcados como online"
    end
  end
  
  desc "Estadísticas detalladas de ubicaciones (físicas vs online)"
  task location_stats: :environment do
    puts "📊 ESTADÍSTICAS DETALLADAS DE UBICACIONES"
    puts "=" * 60
    
    total = Tournament.count
    online = Tournament.online_tournaments.count
    physical = Tournament.physical_tournaments.count
    with_city = Tournament.where.not(city: [nil, '']).count
    with_region = Tournament.where.not(region: [nil, '']).count
    without_location = Tournament.where(city: [nil, ''], region: [nil, '']).count
    
    puts "🎯 RESUMEN GENERAL:"
    puts "   Total de torneos: #{total}"
    puts "   🌐 Torneos online: #{online} (#{percentage(online, total)}%)"
    puts "   📍 Torneos físicos: #{physical} (#{percentage(physical, total)}%)"
    puts "   🏙️  Con ciudad: #{with_city} (#{percentage(with_city, total)}%)"
    puts "   🗺️  Con región: #{with_region} (#{percentage(with_region, total)}%)"
    puts "   ❓ Sin ubicación: #{without_location} (#{percentage(without_location, total)}%)"
    
    puts "\n🌐 DETALLE DE REGIONES:"
    regions = Tournament.where.not(region: [nil, '']).group(:region).count.sort_by { |k, v| v }.reverse
    
    regions.each do |region, count|
      emoji = region == 'Online' ? '🌐' : '📍'
      puts "   #{emoji} #{region}: #{count} (#{percentage(count, total)}%)"
    end
    
    puts "\n🏙️  TOP 10 CIUDADES:"
    cities = Tournament.where.not(city: [nil, '']).group(:city).count.sort_by { |k, v| v }.reverse.first(10)
    
    cities.each do |city, count|
      puts "   📍 #{city}: #{count} (#{percentage(count, total)}%)"
    end
  end
  
  desc "Muestra información detallada de ubicaciones de torneos"
  task show_location_info: :environment do
    puts "📍 Información de ubicaciones de torneos:\n"
    
    Tournament.where.not(venue_address: [nil, '']).limit(20).each do |tournament|
      status_emoji = tournament.online? ? '🌐' : '📍'
      puts "#{status_emoji} #{tournament.name}"
      puts "   Lugar original: #{tournament.venue_address}"
      puts "   Ciudad: #{tournament.city || 'No identificada'}"
      puts "   Región: #{tournament.region || 'No identificada'}"
      puts "   Fecha: #{tournament.start_at&.strftime('%d/%m/%Y') || 'Sin fecha'}"
      puts "   Estado: #{tournament.online? ? 'Online' : 'Físico'}"
      puts ""
    end
  end
  
  desc "Reparsea las ubicaciones de torneos específicos"
  task :reparse_locations, [:tournament_ids] => :environment do |t, args|
    tournament_ids = args[:tournament_ids]&.split(',')&.map(&:to_i)
    
    if tournament_ids.blank?
      puts "❌ Debes proporcionar IDs de torneos separados por comas"
      puts "   Ejemplo: rake tournaments:reparse_locations[1,2,3]"
      next
    end
    
    puts "🔄 Reparsando ubicaciones para torneos: #{tournament_ids.join(', ')}"
    
    service = LocationParserService.new
    updated_count = 0
    
    Tournament.where(id: tournament_ids).each do |tournament|
      puts "   Procesando: #{tournament.name}"
      location_data = service.parse_and_update_tournament(tournament)
      puts "     Ciudad: #{location_data[:city] || 'No identificada'}"
      puts "     Región: #{location_data[:region] || 'No identificada'}"
      puts "     Estado: #{location_data[:region] == 'Online' ? 'Online' : 'Físico'}"
      updated_count += 1
    end
    
    puts "✅ #{updated_count} torneos reparsados."
  end

  private

  def percentage(part, total)
    return 0 if total == 0
    ((part.to_f / total) * 100).round(1)
  end
end 