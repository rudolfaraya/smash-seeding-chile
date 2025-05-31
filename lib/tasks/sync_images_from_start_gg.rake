namespace :images do
  desc "Sincronizar imágenes de torneos desde start.gg"
  task sync_from_start_gg: :environment do
    puts "🖼️ Iniciando sincronización de imágenes de torneos desde start.gg..."

    client = StartGgClient.new

    # Contadores
    tournaments_updated = 0
    total_tournaments = Tournament.where(banner_image_url: [ nil, "" ]).count

    puts "📊 Total de torneos sin imagen: #{total_tournaments}"

    if total_tournaments == 0
      puts "✅ Todos los torneos ya tienen sus imágenes sincronizadas"
      return
    end

    puts ""

    # Sincronizar imágenes de torneos que no las tengan
    puts "🏆 Sincronizando imágenes de torneos sin banner..."
    Tournament.where(banner_image_url: [ nil, "" ]).find_each.with_index(1) do |tournament, index|
      print "   [#{index}/#{total_tournaments}] #{tournament.name}..."

      if tournament.sync_banner_image_from_start_gg!
        tournaments_updated += 1
        puts " ✅"
      else
        puts " ⚪ (sin imagen)"
      end

      # Rate limiting
      sleep(1.5) if index % 10 == 0
    end

    puts ""
    puts "🎉 SINCRONIZACIÓN COMPLETADA"
    puts "=" * 50
    puts "📊 ESTADÍSTICAS FINALES:"
    puts "   🏆 Torneos actualizados: #{tournaments_updated}"
    puts "   📸 Total torneos procesados: #{total_tournaments}"
    puts ""
    puts "💡 NOTA: Las imágenes ahora se sincronizan automáticamente"
    puts "   cuando se crean nuevos torneos con 'sync_new_tournaments'"
  end

  desc "Verificar estado de sincronización de imágenes"
  task check_status: :environment do
    puts "📊 ESTADO DE SINCRONIZACIÓN DE IMÁGENES"
    puts "=" * 50

    total_tournaments = Tournament.count
    tournaments_with_images = Tournament.where.not(banner_image_url: [ nil, "" ]).count
    tournaments_without_images = total_tournaments - tournaments_with_images

    percentage = total_tournaments > 0 ? (tournaments_with_images.to_f / total_tournaments * 100).round(1) : 0

    puts "🏆 Total de torneos: #{total_tournaments}"
    puts "🖼️ Con imágenes: #{tournaments_with_images} (#{percentage}%)"
    puts "⚪ Sin imágenes: #{tournaments_without_images}"
    puts ""

    if tournaments_without_images > 0
      puts "💡 Para sincronizar las imágenes faltantes, ejecuta:"
      puts "   rails images:sync_from_start_gg"
    else
      puts "✅ Todos los torneos tienen sus imágenes sincronizadas"
    end
  end

  desc "Sincronizar imágenes solo de torneos desde start.gg (alias)"
  task sync_tournaments: :sync_from_start_gg

  desc "Mostrar estadísticas de imágenes sincronizadas"
  task stats: :environment do
    puts "📊 Estadísticas de imágenes sincronizadas"
    puts "=" * 50

    tournaments_with_images = Tournament.where.not(banner_image_url: nil).count
    total_tournaments = Tournament.count
    tournaments_percentage = (tournaments_with_images.to_f / total_tournaments * 100).round(1)

    puts "🏆 Torneos:"
    puts "   Con imagen: #{tournaments_with_images}/#{total_tournaments} (#{tournaments_percentage}%)"
    puts "   Sin imagen: #{total_tournaments - tournaments_with_images}"
    puts ""

    # Mostrar algunos ejemplos
    puts "🖼️ Ejemplos de torneos con imagen:"
    Tournament.where.not(banner_image_url: nil).limit(5).each do |tournament|
      puts "   • #{tournament.name} - #{tournament.banner_image_dimensions}"
    end
  end
end
