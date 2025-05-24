namespace :tournaments do
  desc "Marca como online todos los torneos que tienen venue_address: 'Chile'"
  task mark_chile_as_online: :environment do
    puts "🌐 MARCANDO TORNEOS CON VENUE_ADDRESS 'Chile' COMO ONLINE"
    puts "=" * 60
    
    # Buscar todos los torneos con venue_address: "Chile"
    chile_tournaments = Tournament.where(venue_address: 'Chile')
    total_count = chile_tournaments.count
    
    puts "🔍 Encontrados #{total_count} torneos con venue_address: 'Chile'"
    
    if total_count == 0
      puts "✅ No hay torneos para procesar."
      next
    end
    
    updated_count = 0
    already_online_count = 0
    
    chile_tournaments.find_each do |tournament|
      if tournament.online?
        already_online_count += 1
        puts "   🌐 Ya online: #{tournament.name} (#{tournament.start_at&.strftime('%d/%m/%Y')})"
      else
        # Marcar como online
        tournament.update_columns(city: nil, region: 'Online')
        updated_count += 1
        puts "   ✅ Marcado como online: #{tournament.name} (#{tournament.start_at&.strftime('%d/%m/%Y')})"
      end
    end
    
    puts "\n📊 RESUMEN:"
    puts "   Total procesados: #{total_count}"
    puts "   🆕 Marcados como online: #{updated_count}"
    puts "   🌐 Ya eran online: #{already_online_count}"
    
    # Estadísticas finales
    total_online_tournaments = Tournament.online_tournaments.count
    total_tournaments = Tournament.count
    online_percentage = ((total_online_tournaments.to_f / total_tournaments) * 100).round(1)
    
    puts "\n🌐 ESTADÍSTICAS GENERALES:"
    puts "   Total torneos online: #{total_online_tournaments}"
    puts "   Total torneos: #{total_tournaments}"
    puts "   Porcentaje online: #{online_percentage}%"
    
    puts "\n✅ Tarea completada exitosamente!"
  end
  
  desc "Muestra información sobre torneos con venue_address: 'Chile'"
  task show_chile_tournaments: :environment do
    puts "🔍 INFORMACIÓN DE TORNEOS CON VENUE_ADDRESS 'Chile'"
    puts "=" * 60
    
    chile_tournaments = Tournament.where(venue_address: 'Chile').order(:start_at)
    
    if chile_tournaments.empty?
      puts "❌ No se encontraron torneos con venue_address: 'Chile'"
      next
    end
    
    puts "📋 Total encontrados: #{chile_tournaments.count}"
    puts ""
    
    chile_tournaments.each_with_index do |tournament, index|
      status_emoji = tournament.online? ? '🌐' : '📍'
      status_text = tournament.online? ? 'Online' : 'Físico'
      
      puts "#{index + 1}. #{status_emoji} #{tournament.name}"
      puts "   📅 Fecha: #{tournament.start_at&.strftime('%d/%m/%Y') || 'Sin fecha'}"
      puts "   🏟️  Venue: #{tournament.venue_address}"
      puts "   🗺️  Región: #{tournament.region || 'Sin región'}"
      puts "   📊 Estado: #{status_text}"
      puts ""
    end
  end
end 