class Event < ApplicationRecord
  belongs_to :tournament
  has_many :event_seeds, dependent: :destroy
  has_many :players, through: :event_seeds

  validates :slug, presence: true
  validates :name, presence: true

  # Asegurar que el ID del evento de Start.gg (si se conoce) sea único por torneo
  validates :start_gg_event_id, uniqueness: { scope: :tournament_id, allow_nil: true }, if: :start_gg_event_id_present?

  # Callback para generar la URL de start.gg del evento
  before_save :generate_start_gg_event_url, if: :slug_changed?
  
  # Scope para precargar detalles de seeds para cada evento
  scope :with_seed_details, -> {
    select('events.*, COUNT(DISTINCT event_seeds.id) AS event_seeds_count_data, EXISTS(SELECT 1 FROM event_seeds WHERE event_seeds.event_id = events.id) AS has_seeds_data')
      .left_joins(:event_seeds)
      .group('events.id')
  }

  def calculated_event_seeds_count
    if attributes.key?('event_seeds_count_data')
      attributes['event_seeds_count_data']
    else
      event_seeds.size # Eficiente debido al includes(events: [:event_seeds]) en el controlador de torneos
    end
  end

  def has_seeds?
    if attributes.key?('has_seeds_data')
      attributes['has_seeds_data']
    else
      event_seeds.exists? # Eficiente
    end
  end

  # Método para verificar si start_gg_event_id está presente y no es 0
  def start_gg_event_id_present?
    start_gg_event_id.present? && start_gg_event_id != 0
  end

  # Generar la URL del evento en start.gg
  def generate_start_gg_event_url
    if slug.present? && tournament&.slug.present?
      event_specific_slug = self.slug.starts_with?(tournament.slug) ? self.slug.split('/').last : self.slug
      "https://www.start.gg/#{tournament.slug}/event/#{event_specific_slug}"
    end
  end
  
  # Método para obtener la URL de start.gg del evento
  def start_gg_event_url_or_generate
    if slug.present? && tournament&.slug.present?
      event_specific_slug = self.slug.starts_with?(tournament.slug) ? self.slug.split('/').last : self.slug
      "https://www.start.gg/#{tournament.slug}/event/#{event_specific_slug}"
    else
      nil
    end
  end

  def fetch_and_save_seeds(max_retries = 3, retry_delay = 60, force: false)
    # Si es una sincronización forzada, limpiar seeds existentes
    if force
      Rails.logger.info "Sincronización forzada: eliminando #{event_seeds.count} seeds existentes para #{name}"
      event_seeds.destroy_all
    else
      # Verificar si ya hay event seeds para este evento (solo si no es forzado)
      return if event_seeds.any?
    end

    if tournament.name == "La Gagoleta 3: Edición Loki" && name == "Singles"
      Rails.logger.info "Usando datos simulados para La Gagoleta 3: Edición Loki - Singles"
      simulate_la_gagolet_seeds
      return
    end

    Rails.logger.info "Sincronizando seeds y jugadores para el evento: #{name} (Torneo: #{tournament.name})"
    retries = 0

    begin
      # Obtener seeds desde la API usando la lógica de fetch_seeds_sequentially
      seeds_data = fetch_seeds_sequentially(tournament.slug, slug)

      # Guardar cada seed y su jugador en la base de datos
      seeds_data.each do |seed_data|
        entrant = seed_data["entrant"]
        next unless entrant && entrant["participants"].present?

        player_data = entrant["participants"].first["player"]
        user = player_data["user"] || {}
        player = Player.find_or_create_by(user_id: user["id"]) do |p|
          p.id = player_data["id"]
          p.entrant_name = entrant["name"]
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

        EventSeed.find_or_create_by(event: self, player: player) do |es|
          es.seed_num = seed_data["seedNum"] || seed_data["placement"] || nil # Ajusta según el campo real
          es.character_stock_icon = player.character_stock_icon
        end
        Rails.logger.info "Seed guardado: #{entrant["name"]} (Seed: #{es.seed_num})"
      end
    rescue Faraday::ClientError => e
      if e.response[:status] == 429
        Rails.logger.warn "Rate limit excedido para evento #{slug} en torneo #{tournament.slug}. Esperando 60 segundos..."
        sleep(retry_delay)
        retry
      elsif e.response[:status] == 503
        if retries < max_retries
          retries += 1
          Rails.logger.warn "Servicio no disponible (503) para evento #{slug}. Reintento #{retries}/#{max_retries} después de #{retry_delay} segundos..."
          sleep(retry_delay)
          retry
        else
          Rails.logger.error "Servicio no disponible (503) después de #{max_retries} reintentos para evento #{slug} en torneo #{tournament.slug}"
          raise "Error 503 persistente: Los servicios de Start.gg no están disponibles."
        end
      elsif [404, 500].include?(e.response[:status])
        Rails.logger.error "Error HTTP #{e.response[:status]} al obtener seeds para evento #{slug} en torneo #{tournament.slug}: #{e.response[:body]}"
        raise "Error HTTP al obtener seeds: #{e.response[:status]} - #{e.response[:body]}"
      else
        Rails.logger.error "Error al obtener seeds para evento #{slug} en torneo #{tournament.slug}: #{e.message}"
        raise
      end
    rescue JSON::ParserError => e
      if e.message.match(/unexpected character: "<!DOCTYPE html/)
        if retries < max_retries
          retries += 1
          Rails.logger.warn "Respuesta HTML inesperada para evento #{slug}. Reintento #{retries}/#{max_retries} después de #{retry_delay} segundos..."
          sleep(retry_delay)
          retry
        else
          Rails.logger.error "Respuesta HTML persistente después de #{max_retries} reintentos para evento #{slug} en torneo #{tournament.slug}"
          raise "Error persistente: La API de Start.gg devolvió HTML en lugar de JSON."
        end
      else
        Rails.logger.error "Error al parsear JSON para evento #{slug}: #{e.message}"
        raise
      end
    rescue StandardError => e
      Rails.logger.error "Error procesando seeds para evento #{name}: #{e.message}"
      raise
    end
    sleep 0.75 # Retraso para respetar los límites de rate limiting (80 solicitudes/minuto)
  end

  private

  def fetch_seeds_sequentially(tournament_slug, event_slug, requests_per_minute = 80)
    seeds = []
    page = 1
    per_page = 1 # Procesar un seed por solicitud para minimizar objetos y respetar rate limiting
    total_pages = nil

    loop do
      begin
        client = StartGgClient.new
        response = client.query(StartGgQueries::EVENT_PARTICIPANTS_QUERY,
                               { tournamentSlug: tournament_slug,
                                 eventSlug: event_slug,
                                 perPage: per_page,
                                 page: page },
                               "EventParticipants")
        event = response["data"]["tournament"]["events"].first
        data = event["standings"] || event["sets"] || event["seeds"] # Usa el campo correcto según el esquema
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
          Rails.logger.warn "Rate limit excedido para torneo #{tournament_slug}, evento #{event_slug}, página #{page}. Esperando 60 segundos..."
          sleep(60)
          next
        elsif e.response[:status] == 503
          Rails.logger.warn "Servicio no disponible (503) para torneo #{tournament_slug}, evento #{event_slug}, página #{page}. Reintentando en 60 segundos..."
          sleep(60)
          next
        elsif [404, 500].include?(e.response[:status])
          Rails.logger.error "Error HTTP #{e.response[:status]} al obtener seeds para torneo #{tournament_slug}, evento #{event_slug}, página #{page}: #{e.response[:body]}"
          raise "Error HTTP al obtener seeds: #{e.response[:status]} - #{e.response[:body]}"
        else
          Rails.logger.error "Error al obtener seeds para torneo #{tournament_slug}, evento #{event_slug}, página #{page}: #{e.message}"
          raise
        end
      rescue JSON::ParserError => e
        if e.message.match(/unexpected character: "<!DOCTYPE html/)
          Rails.logger.warn "Respuesta HTML inesperada para torneo #{tournament_slug}, evento #{event_slug}, página #{page}. Reintentando en 60 segundos..."
          sleep(60)
          next
        else
          Rails.logger.error "Error al parsear JSON para torneo #{tournament_slug}, evento #{event_slug}, página #{page}: #{e.message}"
          raise
        end
      end
      break if page >= total_pages
      page += 1
      sleep 0.75 # Retraso de 0.75 segundos entre solicitudes (80 solicitudes/minuto = ~0.75s por solicitud)
    ensure
      requests_made = (Time.now - Time.now.beginning_of_minute).to_i / 60 * requests_per_minute
      if requests_made >= requests_per_minute
        elapsed_time = Time.now - Time.now.beginning_of_minute
        if elapsed_time < 60
          sleep_time = 60 - elapsed_time
          Rails.logger.warn "Alcanzado límite de solicitudes (#{requests_per_minute}/min). Esperando #{sleep_time} segundos..."
          sleep(sleep_time)
        end
      end
    end
    seeds
  end

  def simulate_la_gagolet_seeds
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
      EventSeed.create(
        event: self,
        player: player,
        seed_num: seed_num,
        character_stock_icon: player&.character_stock_icon
      )
    end
  end
end
