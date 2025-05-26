require_relative "../../lib/start_gg_queries"
require "set"

class SyncSmashData
  def initialize(update_players: false)
    @client = StartGgClient.new
    @update_players = update_players
  end

  def call
    sync_tournaments
  end

  # Sincronizar todos los torneos y priorizar eventos faltantes
  def sync_tournaments
    Rails.logger.info "Sincronizando todos los torneos y priorizando eventos faltantes..."

    # Primero sincronizar eventos faltantes en torneos existentes
    sync_missing_events_for_existing_tournaments

    # Luego sincronizar todos los torneos nuevos
    sync_all_tournaments_with_events
  end

  # Sincronizar solo torneos nuevos (posteriores a la fecha del último torneo)
  def sync_tournaments_and_events_atomic
    Rails.logger.info "Sincronizando solo torneos nuevos..."

    # Obtener la fecha del último torneo en la base de datos
    last_tournament = Tournament.order(start_at: :desc).first
    last_tournament_date = last_tournament&.start_at

    if last_tournament_date
      Rails.logger.info "Buscando torneos posteriores a: #{last_tournament_date}"
    else
      Rails.logger.info "No hay torneos en la base de datos, sincronizando todos"
    end

    sync_new_tournaments_since_date(last_tournament_date)
  end

  # Sincronizar eventos faltantes en torneos que no tengan eventos
  def sync_missing_events_for_existing_tournaments
    Rails.logger.info "Sincronizando eventos faltantes en torneos existentes..."

    # Buscar torneos que no tengan eventos sincronizados
    tournaments_without_events = Tournament.left_joins(:events)
                                          .where(events: { id: nil })
                                          .order(start_at: :desc)

    Rails.logger.info "Encontrados #{tournaments_without_events.count} torneos sin eventos"

    tournaments_without_events.each do |tournament|
      sync_events_for_single_tournament(tournament)
      sleep 2 # Pausa entre torneos para evitar rate limits
    end
  end

  # Sincronizar todos los torneos con sus eventos uno a uno
  def sync_all_tournaments_with_events
    Rails.logger.info "Sincronizando todos los torneos desde la API..."
    count_before = Tournament.count
    nuevos_torneos = 0

    # Obtener todos los torneos desde la API
    torneo_data_list = StartGgQueries.fetch_tournaments(@client, per_page: 25)

    torneo_data_list.each do |torneo_data|
      # Verificar si el torneo ya existe
      tournament = Tournament.find_by(id: torneo_data["id"])

      if tournament.nil?
        # Procesar torneo nuevo uno a uno
        nuevos_torneos += sync_single_tournament_with_events(torneo_data)
        sleep 2 # Pausa entre torneos
      end
    end

    count_after = Tournament.count
    Rails.logger.info "Sincronización completada. Se agregaron #{nuevos_torneos} nuevos torneos. Total: #{count_after} torneos."
    nuevos_torneos
  end

  # Sincronizar torneos nuevos desde una fecha específica (OPTIMIZADO)
  def sync_new_tournaments_since_date(since_date)
    Rails.logger.info "🚀 Sincronizando torneos nuevos desde: #{since_date || 'el inicio'}"
    count_before = Tournament.count
    nuevos_torneos = 0

    # Obtener IDs de torneos existentes en la base de datos para verificación rápida
    existing_tournament_ids = Tournament.pluck(:id).to_set
    Rails.logger.info "📋 Torneos existentes en BD: #{existing_tournament_ids.count}"

    begin
      # Usar el nuevo método optimizado que filtra en la API
      torneo_data_list = StartGgQueries.fetch_tournaments_since_date(@client, since_date, 25)
      Rails.logger.info "🎯 Torneos obtenidos de la API: #{torneo_data_list.count}"

      # Filtrar solo torneos que NO existen en la base de datos
      torneos_nuevos = torneo_data_list.reject do |torneo_data|
        existing_tournament_ids.include?(torneo_data["id"])
      end

      Rails.logger.info "✨ Torneos realmente nuevos para procesar: #{torneos_nuevos.count}"

      if torneos_nuevos.empty?
        Rails.logger.info "💭 No hay torneos nuevos para sincronizar"
        return 0
      end

      # Procesar solo los torneos realmente nuevos
      torneos_nuevos.each_with_index do |torneo_data, index|
        Rails.logger.info "⚡ Procesando torneo #{index + 1}/#{torneos_nuevos.count}: #{torneo_data['name']}"

        # Verificar una vez más que no existe (por si acaso)
        unless Tournament.exists?(id: torneo_data["id"])
          nuevos_torneos += sync_single_tournament_with_events(torneo_data)

          # Pausa progresiva: más corta para pocos torneos, más larga para muchos
          if torneos_nuevos.count <= 5
            sleep 1.5
          elsif torneos_nuevos.count <= 15
            sleep 2
          else
            sleep 2.5
          end
        else
          Rails.logger.warn "⚠️  Torneo #{torneo_data['name']} ya existe, saltando"
        end
      end

    rescue StandardError => e
      Rails.logger.error "❌ Error en sincronización optimizada: #{e.message}"
      # Intentar con método de respaldo si falla
      Rails.logger.info "🔄 Intentando con método de respaldo..."
      return sync_new_tournaments_since_date_fallback(since_date)
    end

    count_after = Tournament.count
    Rails.logger.info "🎉 Sincronización completada exitosamente!"
    Rails.logger.info "📊 Resumen:"
    Rails.logger.info "   • Torneos nuevos agregados: #{nuevos_torneos}"
    Rails.logger.info "   • Total torneos antes: #{count_before}"
    Rails.logger.info "   • Total torneos después: #{count_after}"
    Rails.logger.info "   • Diferencia real: #{count_after - count_before}"

    nuevos_torneos
  end

  # Método de respaldo para sincronización de nuevos torneos
  def sync_new_tournaments_since_date_fallback(since_date)
    Rails.logger.info "🔄 Usando método de respaldo para sincronización"
    count_before = Tournament.count
    nuevos_torneos = 0

    # Obtener todos los torneos y filtrar manualmente
    torneo_data_list = StartGgQueries.fetch_tournaments(@client, per_page: 25)

    # Filtrar por fecha si se especifica
    if since_date
      torneo_data_list = torneo_data_list.select do |torneo_data|
        tournament_date = torneo_data["startAt"] ? Time.at(torneo_data["startAt"]) : nil
        tournament_date && tournament_date > since_date
      end
    end

    Rails.logger.info "📄 Torneos filtrados por fecha: #{torneo_data_list.count}"

    # Filtrar solo torneos que no existen en la base de datos
    torneo_data_list.each do |torneo_data|
      unless Tournament.exists?(id: torneo_data["id"])
        nuevos_torneos += sync_single_tournament_with_events(torneo_data)
        sleep 2
      end
    end

    count_after = Tournament.count
    Rails.logger.info "✅ Sincronización de respaldo completada: #{nuevos_torneos} nuevos torneos agregados"
    nuevos_torneos
  end

  # Sincronizar un solo torneo con sus eventos de forma atómica
  def sync_single_tournament_with_events(torneo_data)
    ActiveRecord::Base.transaction do
      # Verificar si es un torneo online
      parser = LocationParserService.new
      is_online = parser.send(:online_tournament?, torneo_data["venueAddress"] || "") ||
                  parser.send(:online_tournament_by_name?, torneo_data["name"] || "")

      # Crear el torneo
      tournament = Tournament.create!(
        id: torneo_data["id"],
        name: torneo_data["name"],
        slug: torneo_data["slug"],
        start_at: torneo_data["startAt"] ? Time.at(torneo_data["startAt"]) : nil,
        end_at: torneo_data["endAt"] ? Time.at(torneo_data["endAt"]) : nil,
        venue_address: torneo_data["venueAddress"],
        start_gg_url: torneo_data["slug"].present? ? "https://www.start.gg/#{torneo_data["slug"]}" : nil,
        region: is_online ? "Online" : nil,
        city: is_online ? nil : nil,
        attendees_count: torneo_data["numAttendees"]
      )

      status_emoji = tournament.online? ? "🌐" : "📍"
      location_info = tournament.online? ? "Online" : tournament.venue_address
      Rails.logger.info "✅ Creado torneo #{status_emoji}: #{tournament.name} (#{tournament.start_at}) - #{location_info} - URL: #{tournament.start_gg_url}"

      # Sincronizar eventos para este torneo inmediatamente
      sync_events_for_single_tournament(tournament)

      # Actualizar información de jugadores si está habilitado
      if @update_players
        Rails.logger.info "🔄 Actualizando información de jugadores del torneo: #{tournament.name}"
        update_service = UpdatePlayersService.new(
          delay_between_requests: 1.second,
          force_update: false
        )
        update_service.update_players_from_tournament_sync(tournament)
      end

      Rails.logger.info "✅ Torneo sincronizado exitosamente: #{tournament.name}"
      return 1 # Retorna 1 torneo creado
    end
  rescue StandardError => e
    Rails.logger.error "❌ Error al crear torneo #{torneo_data['name']}: #{e.message}"
    0 # No se creó ningún torneo
  end

  # Sincronizar eventos para un torneo específico
  def sync_events_for_single_tournament(tournament)
    Rails.logger.info "  🔄 Sincronizando eventos para: #{tournament.name}"
    count_before = tournament.events.count

    begin
      events_data = fetch_events(tournament.slug)

      events_data.each do |event_data|
        Event.find_or_create_by(tournament: tournament, slug: event_data["slug"]) do |event|
          event.name = event_data["name"]
          event.id = event_data["id"]
        end
      end

      count_after = tournament.events.reload.count
      new_events = count_after - count_before
      Rails.logger.info "  ✅ Se crearon #{new_events} eventos para #{tournament.name}"

      new_events
    rescue StandardError => e
      Rails.logger.error "  ❌ Error al sincronizar eventos para #{tournament.name}: #{e.message}"
      0
    end
  end

  private

  def fetch_events(slug)
    response = @client.query(StartGgQueries::EVENTS_QUERY, { tournamentSlug: slug }, "TournamentEvents")
    response["data"]["tournament"]["events"]
  rescue Faraday::ClientError => e
    if e.response[:status] == 429
      retry_after = e.response[:headers]["Retry-After"]&.to_i || 60
      Rails.logger.warn "Rate limit excedido para torneo #{slug}. Esperando #{retry_after} segundos..."
      sleep(retry_after)
      retry
    elsif [ 404, 500 ].include?(e.response[:status])
      Rails.logger.error "Error HTTP #{e.response[:status]} al obtener eventos para torneo #{slug}: #{e.response[:body]}"
      raise "Error HTTP al obtener eventos: #{e.response[:status]} - #{e.response[:body]}"
    else
      Rails.logger.error "Error al obtener eventos para torneo #{slug}: #{e.message}"
      raise
    end
  end

  def simulate_la_gagolet_seeds(tournament)
    players_data = [
      { id: 1, entrant_name: "🔺 Leoxe", name: "Leoxe", user_id: 1, twitter_handle: "leoxe_smash", character_stock_icon: "villager" },
      { id: 2, entrant_name: "🍁 Xupapapa", name: "Xupapapa", user_id: 2, twitter_handle: "xupapapa_ssbu", character_stock_icon: "peach" },
      { id: 3, entrant_name: "⬜ yeki", name: "yeki", user_id: 3, twitter_handle: "yeki_ssbu", character_stock_icon: "pikachu" },
      { id: 4, entrant_name: "Chayanne", name: "Chayanne", user_id: 4, twitter_handle: "chayanne_smash", character_stock_icon: "jigglypuff" },
      { id: 5, entrant_name: "Radiant", name: "Radiant", user_id: 5, twitter_handle: "radiant_ssbu", character_stock_icon: "zelda" },
      { id: 6, entrant_name: "⬜ Ainwind", name: "Ainwind", user_id: 6, twitter_handle: "ainwind_smash", character_stock_icon: "link" },
      { id: 7, entrant_name: "⬜ JajaSC", name: "JajaSC", user_id: 7, twitter_handle: "jajasc_ssbu", character_stock_icon: "mario" },
      { id: 8, entrant_name: "🔺 Buttero", name: "Buttero", user_id: 8, twitter_handle: "buttero_smash", character_stock_icon: "kirby" },
      { id: 9, entrant_name: "⬜ Poiolpo-X", name: "Poiolpo-X", user_id: 9, twitter_handle: "poiolpo_x_ssbu", character_stock_icon: "fox" },
      { id: 10, entrant_name: "⬜ Gago", name: "Gago", user_id: 10, twitter_handle: "gago_ssbu", character_stock_icon: "bowser" },
      { id: 11, entrant_name: "Mazon", name: "Mazon", user_id: 11, twitter_handle: "mazon_smash", character_stock_icon: "ness" },
      { id: 12, entrant_name: "⬜ secret", name: "secret", user_id: 12, twitter_handle: "secret_ssbu", character_stock_icon: "samus" },
      { id: 13, entrant_name: "⬜ marr", name: "marr", user_id: 13, twitter_handle: "marr_ssbu", character_stock_icon: "marth" },
      { id: 14, entrant_name: "⬜ Rodo", name: "Rodo", user_id: 14, twitter_handle: "rodo_smash", character_stock_icon: "luigi" },
      { id: 15, entrant_name: "⬜ Hvniel07", name: "Hvniel07", user_id: 15, twitter_handle: "hvniel07_ssbu", character_stock_icon: "pit" },
      { id: 16, entrant_name: "⬜ Shaska", name: "Shaska", user_id: 16, twitter_handle: "shaska_smash", character_stock_icon: "robin" },
      { id: 17, entrant_name: "Rch23#", name: "Rch23#", user_id: 17, twitter_handle: "rch23_ssbu", character_stock_icon: "ike" },
      { id: 18, entrant_name: "⬜ Riben", name: "Riben", user_id: 18, twitter_handle: "riben_smash", character_stock_icon: "captain" },
      { id: 19, entrant_name: "⬜ Criollo110", name: "Criollo110", user_id: 19, twitter_handle: "criollo110_ssbu", character_stock_icon: "falco" },
      { id: 20, entrant_name: "Benoo110", name: "Benoo110", user_id: 20, twitter_handle: "benoo110_smash", character_stock_icon: "sheik" },
      { id: 21, entrant_name: "⬜ Agusaurio", name: "Agusaurio", user_id: 21, twitter_handle: "agusaurio_ssbu", character_stock_icon: "peach" },
      { id: 22, entrant_name: "⬜ Amadeu", name: "Amadeu", user_id: 22, twitter_handle: "amadeu_smash", character_stock_icon: "toon_link" },
      { id: 23, entrant_name: "Disponible", name: "Disponible", user_id: 23, twitter_handle: nil, character_stock_icon: nil },
      { id: 24, entrant_name: "Disponible", name: "Disponible", user_id: 24, twitter_handle: nil, character_stock_icon: nil }
    ]

    players_data.each do |data|
      Player.find_or_create_by(user_id: data[:user_id]) do |p|
        p.id = data[:id]
        p.entrant_name = data[:entrant_name]
        p.name = data[:name]
        p.twitter_handle = data[:twitter_handle]
        p.character_stock_icon = data[:character_stock_icon]
      end
    end

    (1..24).each do |seed_num|
      player = Player.find_by(id: seed_num)
      event = Event.find_or_create_by(tournament: tournament, name: "Singles", slug: "singles")
      EventSeed.create(
        event: event,
        player: player,
        seed_num: seed_num,
        character_stock_icon: player&.character_stock_icon
      )
    end
  end
end
