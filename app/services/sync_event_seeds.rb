require_relative "../../lib/start_gg_queries"

class SyncEventSeeds
  def initialize(event)
    @event = event
    @client = StartGgClient.new
  end

  def call
    Rails.logger.info "Sincronizando seeds y jugadores para el evento: #{@event.name}"
    seeds_data = fetch_seeds_sequentially(@event.tournament.slug, @event.slug)
    seeds_data.each do |seed_data|
      entrant = seed_data["entrant"]
      next unless entrant && entrant["participants"].present?

      player_data = entrant["participants"].first["player"]
      user = player_data["user"] || {}
      player = Player.find_or_create_by(user_id: user["id"]) do |p|
        p.id = player_data["id"]
        p.entrant_name = entrant["name"]
        p.user_slug = user["slug"]
        p.name = user["name"]
        p.discriminator = user["discriminator"]
        p.bio = user["bio"]
        location = user["location"] || {}
        p.city = location["city"]
        p.state = location["state"]
        p.country = location["country"]
        p.gender_pronoun = user["genderPronoun"]
        p.birthday = user["birthday"]
        p.twitter_handle = user["authorizations"]&.first&.dig("externalUsername")
        p.character_stock_icon = nil
      end

      EventSeed.find_or_create_by(event: @event, player: player) do |es|
        es.seed_num = seed_data["seedNum"] || nil
        es.character_stock_icon = player.character_stock_icon
      end
    rescue StandardError => e
      Rails.logger.error "Error procesando seed para evento #{@event.name}: #{e.message}"
      raise
    end
    Rails.logger.info "Guardados #{EventSeed.where(event: @event).count} seeds para el evento #{@event.name}."
  end

  private

  def fetch_seeds_sequentially(tournament_slug, event_slug, requests_per_minute = 80)
    seeds = []
    page = 1
    per_page = 1 # Procesar un seed por solicitud para minimizar objetos y respetar rate limiting
    total_pages = nil

    loop do
      begin
        response = @client.query(StartGgQueries::EVENT_PARTICIPANTS_QUERY, 
                              { tournamentSlug: tournament_slug, 
                                eventSlug: event_slug, 
                                perPage: per_page, 
                                page: page }, 
                              "EventParticipants")
        event = response["data"]["tournament"]["events"].first
        data = event["standings"] || event["sets"] # Usa "standings" o "sets" según el esquema
        data["nodes"].each do |node|
          seeds << {
            id: node["id"],
            seedNum: node["placement"] || node["seedNum"] || nil, # Ajusta según el campo real
            entrant: node["entrant"] || (node["entrant1"] || node["entrant2"])
          }
        end
        total_pages ||= data["pageInfo"]["totalPages"]
      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          retry_after = e.response[:headers]["Retry-After"]&.to_i || 60
          Rails.logger.warn "Rate limit excedido para torneo #{tournament_slug}, evento #{event_slug}, página #{page}. Esperando #{retry_after} segundos..."
          sleep(retry_after)
          next
        elsif [404, 500].include?(e.response[:status])
          Rails.logger.error "Error HTTP #{e.response[:status]} al obtener seeds para torneo #{tournament_slug}, evento #{event_slug}, página #{page}: #{e.response[:body]}"
          raise "Error HTTP al obtener seeds: #{e.response[:status]} - #{e.response[:body]}"
        else
          Rails.logger.error "Error al obtener seeds para torneo #{tournament_slug}, evento #{event_slug}, página #{page}: #{e.message}"
          raise
        end
      end
      break if page >= total_pages
      page += 1
      sleep 0.75 # Retraso de 0.75 segundos entre solicitudes (80 solicitudes/minuto = ~0.75s por solicitud)
    end
    seeds
  end
end
