require_relative "../../lib/start_gg_queries"

class SyncSmashData
  def initialize
    @client = StartGgClient.new
  end

  def call
    # ync_tournaments
    sync_events
  end

  private

  def sync_tournaments
    Rails.logger.info "Sincronizando torneos..."
    StartGgQueries.fetch_tournaments(@client, per_page: 25).each do |data|
      Tournament.find_or_create_by(id: data["id"]) do |t|
        t.name = data["name"]
        t.slug = data["slug"]
        t.start_at = Time.at(data["startAt"]) if data["startAt"]
        t.end_at = Time.at(data["endAt"]) if data["endAt"]
        t.venue_address = data["venueAddress"]
      end
    end
    Rails.logger.info "Guardados #{Tournament.count} torneos."
  end

  def sync_events
    Rails.logger.info "Sincronizando eventos..."
    Tournament.order(start_at: :desc).each do |tournament|
      Rails.logger.info "Procesando torneo: #{tournament.name} (Fecha: #{tournament.start_at})"
      begin
        events_data = fetch_events(tournament.slug)
        events_data.each do |event_data|
          Event.find_or_create_by(tournament: tournament, slug: event_data["slug"]) do |event|
            event.name = event_data["name"]
            event.id = event_data["id"]
          end
        rescue StandardError => e
          Rails.logger.error "Error procesando eventos para torneo #{tournament.name}: #{e.message}"
          next
        end
      end
      sleep 5 # Retraso entre torneos para evitar rate limits
    end
    Rails.logger.info "Guardados #{Event.count} eventos."
  end

  def fetch_events(slug)
    response = @client.query(StartGgQueries::EVENTS_QUERY, { tournamentSlug: slug }, "TournamentEvents")
    response["data"]["tournament"]["events"]
  rescue Faraday::ClientError => e
    if e.response[:status] == 429
      retry_after = e.response[:headers]["Retry-After"]&.to_i || 60
      Rails.logger.warn "Rate limit excedido para torneo #{slug}. Esperando #{retry_after} segundos..."
      sleep(retry_after)
      retry
    elsif [404, 500].include?(e.response[:status])
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
