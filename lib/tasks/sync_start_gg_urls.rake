namespace :tournaments do
  desc "Sincronizar URLs de start.gg para todos los torneos existentes"
  task :sync_start_gg_urls => :environment do
    puts "🔗 SINCRONIZACIÓN DE URLs DE START.GG"
    puts "=" * 60
    
    # Obtener todos los torneos que no tienen URL o necesitan actualizar
    tournaments_needing_update = Tournament.where(start_gg_url: [nil, ""])
                                          .or(Tournament.where.not(slug: nil))
    
    total_tournaments = tournaments_needing_update.count
    updated_count = 0
    error_count = 0
    
    puts "📊 Torneos a procesar: #{total_tournaments}"
    
    if total_tournaments == 0
      puts "✅ Todos los torneos ya tienen sus URLs de start.gg sincronizadas"
      exit 0
    end
    
    puts "🚀 Iniciando sincronización..."
    puts "-" * 60
    
    tournaments_needing_update.find_each.with_index do |tournament, index|
      begin
        # Mostrar progreso
        progress = ((index + 1).to_f / total_tournaments * 100).round(1)
        print "\r🔄 Procesando: #{index + 1}/#{total_tournaments} (#{progress}%) - #{tournament.name[0..50]}..."
        
        if tournament.slug.present?
          # Generar la URL
          new_url = "https://www.start.gg/#{tournament.slug}"
          
          # Actualizar solo si es diferente
          if tournament.start_gg_url != new_url
            tournament.update_column(:start_gg_url, new_url)
            updated_count += 1
          end
        else
          puts "\n⚠️  Torneo sin slug: #{tournament.name} (ID: #{tournament.id})"
        end
        
      rescue StandardError => e
        error_count += 1
        puts "\n❌ Error procesando torneo #{tournament.name} (ID: #{tournament.id}): #{e.message}"
      end
    end
    
    puts "\n" + "=" * 60
    puts "🎉 SINCRONIZACIÓN COMPLETADA"
    puts "=" * 60
    puts "📊 ESTADÍSTICAS:"
    puts "   🏆 Total procesados: #{total_tournaments}"
    puts "   ✅ URLs actualizadas: #{updated_count}"
    puts "   ❌ Errores: #{error_count}"
    
    if error_count > 0
      puts "\n⚠️  Se encontraron #{error_count} errores durante el proceso"
    end
    
    puts "\n✅ Todas las URLs de start.gg han sido sincronizadas"
  end
  
  desc "Verificar y mostrar estadísticas de URLs de start.gg"
  task :check_start_gg_urls => :environment do
    puts "📊 ESTADÍSTICAS DE URLs DE START.GG"
    puts "=" * 50
    
    total_tournaments = Tournament.count
    with_urls = Tournament.where.not(start_gg_url: [nil, ""]).count
    without_urls = total_tournaments - with_urls
    with_slug_no_url = Tournament.where.not(slug: [nil, ""])
                                .where(start_gg_url: [nil, ""]).count
    
    puts "🏆 Total de torneos: #{total_tournaments}"
    puts "✅ Con URL de start.gg: #{with_urls} (#{percentage(with_urls, total_tournaments)}%)"
    puts "❌ Sin URL de start.gg: #{without_urls} (#{percentage(without_urls, total_tournaments)}%)"
    puts "🔧 Con slug pero sin URL: #{with_slug_no_url}"
    
    if without_urls > 0
      puts "\n💡 Para sincronizar las URLs faltantes ejecuta:"
      puts "   bin/rails tournaments:sync_start_gg_urls"
    else
      puts "\n🎉 ¡Todos los torneos tienen sus URLs sincronizadas!"
    end
  end
  
  desc "Mostrar algunos ejemplos de URLs generadas"
  task :show_url_examples => :environment do
    puts "🔗 EJEMPLOS DE URLs DE START.GG"
    puts "=" * 50
    
    Tournament.where.not(start_gg_url: [nil, ""])
              .limit(10)
              .each_with_index do |tournament, index|
      puts "#{index + 1}. #{tournament.name}"
      puts "   🔗 #{tournament.start_gg_url}"
      puts "   📅 #{tournament.start_at&.strftime('%d/%m/%Y')}"
      puts ""
    end
  end
  
  private
  
  def percentage(part, total)
    return 0 if total == 0
    ((part.to_f / total) * 100).round(1)
  end
end 