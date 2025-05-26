namespace :tournaments do
  desc "Actualizar el número de asistentes para todos los torneos desde start.gg"
  task update_attendees_count: :environment do
    puts "🚀 Iniciando actualización del número de asistentes para todos los torneos..."

    client = StartGgClient.new
    tournaments = Tournament.all.order(:start_at)
    total_tournaments = tournaments.count
    updated_count = 0
    error_count = 0

    puts "📊 Total de torneos a procesar: #{total_tournaments}"

    tournaments.each_with_index do |tournament, index|
      begin
        puts "⚡ Procesando #{index + 1}/#{total_tournaments}: #{tournament.name}"

        # Consulta GraphQL para obtener solo el número de asistentes
        query = <<~GRAPHQL
          query TournamentAttendees($slug: String!) {
            tournament(slug: $slug) {
              id
              name
              numAttendees
            }
          }
        GRAPHQL

        variables = { slug: tournament.slug }
        response = client.query(query, variables, "TournamentAttendees")

        if response["data"] && response["data"]["tournament"]
          tournament_data = response["data"]["tournament"]
          attendees_count = tournament_data["numAttendees"]

          if attendees_count
            tournament.update!(attendees_count: attendees_count)
            puts "  ✅ Actualizado: #{attendees_count} asistentes"
            updated_count += 1
          else
            puts "  ⚠️  Sin datos de asistentes disponibles"
          end
        else
          puts "  ❌ No se pudo obtener información del torneo"
          error_count += 1
        end

        # Pausa para evitar rate limits
        sleep 1.5

      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          puts "  ⏱️  Rate limit alcanzado, esperando 60 segundos..."
          sleep 60
          retry
        else
          puts "  ❌ Error HTTP #{e.response[:status]}: #{e.message}"
          error_count += 1
        end
      rescue StandardError => e
        puts "  ❌ Error inesperado: #{e.message}"
        error_count += 1
      end
    end

    puts "\n🎉 Actualización completada!"
    puts "📊 Resumen:"
    puts "   • Total procesados: #{total_tournaments}"
    puts "   • Actualizados exitosamente: #{updated_count}"
    puts "   • Errores: #{error_count}"
    puts "   • Sin cambios: #{total_tournaments - updated_count - error_count}"
  end

  desc "Actualizar el número de asistentes solo para torneos sin este dato"
  task update_missing_attendees_count: :environment do
    puts "🚀 Actualizando número de asistentes solo para torneos que no tienen este dato..."

    client = StartGgClient.new
    tournaments = Tournament.where(attendees_count: nil).order(:start_at)
    total_tournaments = tournaments.count
    updated_count = 0
    error_count = 0

    puts "📊 Torneos sin datos de asistentes: #{total_tournaments}"

    if total_tournaments == 0
      puts "✅ Todos los torneos ya tienen datos de asistentes!"
      return
    end

    tournaments.each_with_index do |tournament, index|
      begin
        puts "⚡ Procesando #{index + 1}/#{total_tournaments}: #{tournament.name}"

        query = <<~GRAPHQL
          query TournamentAttendees($slug: String!) {
            tournament(slug: $slug) {
              id
              name
              numAttendees
            }
          }
        GRAPHQL

        variables = { slug: tournament.slug }
        response = client.query(query, variables, "TournamentAttendees")

        if response["data"] && response["data"]["tournament"]
          tournament_data = response["data"]["tournament"]
          attendees_count = tournament_data["numAttendees"]

          if attendees_count
            tournament.update!(attendees_count: attendees_count)
            puts "  ✅ Actualizado: #{attendees_count} asistentes"
            updated_count += 1
          else
            puts "  ⚠️  Sin datos de asistentes disponibles en start.gg"
          end
        else
          puts "  ❌ No se pudo obtener información del torneo"
          error_count += 1
        end

        sleep 1.5

      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          puts "  ⏱️  Rate limit alcanzado, esperando 60 segundos..."
          sleep 60
          retry
        else
          puts "  ❌ Error HTTP #{e.response[:status]}: #{e.message}"
          error_count += 1
        end
      rescue StandardError => e
        puts "  ❌ Error inesperado: #{e.message}"
        error_count += 1
      end
    end

    puts "\n🎉 Actualización completada!"
    puts "📊 Resumen:"
    puts "   • Total procesados: #{total_tournaments}"
    puts "   • Actualizados exitosamente: #{updated_count}"
    puts "   • Errores: #{error_count}"
  end
end
