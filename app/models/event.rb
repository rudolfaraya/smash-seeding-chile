class Event < ApplicationRecord
  belongs_to :tournament
  has_many :event_seeds, dependent: :destroy
  has_many :players, through: :event_seeds

  validates :slug, presence: true
  validates :name, presence: true

  # Asegurar que el ID del evento de Start.gg (si se conoce) sea único por torneo
  validates :start_gg_event_id, uniqueness: { scope: :tournament_id, allow_nil: true }, if: :start_gg_event_id_present?

  # Constantes para identificación de eventos válidos
  SMASH_ULTIMATE_VIDEOGAME_ID = 1386

  # Scopes para filtrar eventos
  scope :smash_ultimate, -> { where(videogame_id: SMASH_ULTIMATE_VIDEOGAME_ID) }
  scope :singles_only, -> { where("team_max_players IS NULL OR team_max_players <= 1") }
  scope :valid_smash_singles, -> { smash_ultimate.singles_only }

  # Callback para generar la URL de start.gg del evento
  before_save :generate_start_gg_event_url, if: :slug_changed?

  # Scope para precargar detalles de seeds para cada evento
  scope :with_seed_details, -> {
    select("events.*, COUNT(DISTINCT event_seeds.id) AS event_seeds_count_data, EXISTS(SELECT 1 FROM event_seeds WHERE event_seeds.event_id = events.id) AS has_seeds_data")
      .left_joins(:event_seeds)
      .group("events.id")
  }

  def calculated_event_seeds_count
    if attributes.key?("event_seeds_count_data")
      attributes["event_seeds_count_data"]
    else
      event_seeds.size # Eficiente debido al includes(events: [:event_seeds]) en el controlador de torneos
    end
  end

  def has_seeds?
    if attributes.key?("has_seeds_data")
      attributes["has_seeds_data"]
    else
      event_seeds.exists? # Eficiente
    end
  end

  # Método para verificar si start_gg_event_id está presente y no es 0
  def start_gg_event_id_present?
    start_gg_event_id.present? && start_gg_event_id != 0
  end

  # Obtener el número real de participantes registrados en start.gg
  def attendees_count_display
    attendees_count || "No disponible"
  end

  # Verificar si hay discrepancia entre seeds y attendees
  def has_attendees_discrepancy?
    return false unless attendees_count.present?
    (attendees_count - calculated_event_seeds_count).abs > 0
  end

  # Obtener la diferencia entre attendees y seeds
  def attendees_seeds_difference
    return 0 unless attendees_count.present?
    attendees_count - calculated_event_seeds_count
  end

  # Porcentaje de completitud de seeds vs attendees
  def seeds_completeness_percentage
    return 100 unless attendees_count.present? && attendees_count > 0
    ((calculated_event_seeds_count.to_f / attendees_count) * 100).round(1)
  end

  # Métodos para identificar el tipo de evento
  def smash_ultimate?
    videogame_id == SMASH_ULTIMATE_VIDEOGAME_ID
  end

  def singles_event?
    team_max_players.nil? || team_max_players <= 1
  end

  def doubles_event?
    !singles_event?
  end

  def valid_smash_singles?
    smash_ultimate? && singles_event?
  end

  def other_game_event?
    videogame_id.present? && videogame_id != SMASH_ULTIMATE_VIDEOGAME_ID
  end

  # Generar la URL del evento en start.gg
  def generate_start_gg_event_url
    if slug.present? && tournament&.slug.present?
      event_specific_slug = self.slug.starts_with?(tournament.slug) ? self.slug.split("/").last : self.slug
      "https://www.start.gg/#{tournament.slug}/event/#{event_specific_slug}"
    end
  end

  # Método para obtener la URL de start.gg del evento
  def start_gg_event_url_or_generate
    if slug.present? && tournament&.slug.present?
      event_specific_slug = self.slug.starts_with?(tournament.slug) ? self.slug.split("/").last : self.slug
      "https://www.start.gg/#{tournament.slug}/event/#{event_specific_slug}"
    else
      nil
    end
  end

  def fetch_and_save_seeds(force: false, max_retries: 3, retry_delay: 60)
    # Si es una sincronización forzada, limpiar seeds existentes
    if force
      Rails.logger.info "Sincronización forzada: eliminando #{event_seeds.count} seeds existentes para #{name}"
      event_seeds.destroy_all
    else
      # Verificar si ya hay event seeds para este evento (solo si no es forzado)
      return if event_seeds.any?
    end

    # Actualizar la fecha de última sincronización
    update(seeds_last_synced_at: Time.current)

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
          # Removed character_stock_icon as it no longer exists in Player model
        end

        EventSeed.find_or_create_by(event: self, player: player) do |es|
          es.seed_num = seed_data["seedNum"] || seed_data["placement"] || nil # Ajusta según el campo real
          # Set character_stock_icon to nil since Player no longer has this attribute
          es.character_stock_icon = nil
        end
        Rails.logger.info "Seed guardado: #{entrant["name"]} (Seed: #{es.seed_num})"
      end

      Rails.logger.info "✅ Seeds sincronizados para #{name}: #{seeds_data.size} entrants procesados"

      # Si es sincronización forzada, también sincronizar placements
      if force && start_gg_event_id.present?
        Rails.logger.info "🏆 Sincronizando placements para sincronización forzada..."
        fetch_and_save_placements(force: true)
      end

    rescue Faraday::ClientError => e
      retries += 1
      if e.response[:status] == 429 && retries <= max_retries
        Rails.logger.warn "Rate limit excedido para evento #{name}. Reintento #{retries}/#{max_retries} en #{retry_delay} segundos..."
        sleep(retry_delay)
        retry
      else
        Rails.logger.error "Error sincronizando evento #{name}: #{e.message}"
        raise
      end
    rescue StandardError => e
      Rails.logger.error "Error procesando seeds para evento #{name}: #{e.message}"
      raise
    end
    sleep 0.75 # Retraso para respetar los límites de rate limiting (80 solicitudes/minuto)
  end

  # Método para sincronizar placements (resultados finales) desde start.gg
  def fetch_and_save_placements(force: false, max_retries: 3, retry_delay: 60)
    return unless start_gg_event_id.present?

    # Si no es forzado, verificar si ya hay placements
    unless force
      return if event_seeds.where.not(placement: nil).exists?
    end

    Rails.logger.info "🏆 Sincronizando placements para el evento: #{name} (ID: #{start_gg_event_id})"
    retries = 0

    begin
      client = StartGgClient.new
      standings = StartGgQueries.fetch_event_standings(client, start_gg_event_id)

      if standings.empty?
        Rails.logger.warn "⚠️ No se encontraron standings para el evento #{name}"
        return
      end

      updated_count = 0
      created_count = 0

      standings.each do |standing|
        entrant = standing["entrant"]
        next unless entrant && entrant["participants"].present?

        player_data = entrant["participants"].first["player"]
        user = player_data["user"] || {}
        placement = standing["placement"]

        next unless placement.present?

        # Buscar al jugador
        player = if user["id"].present?
          Player.find_by(user_id: user["id"])
        else
          # Fallback: buscar por nombre del entrant
          Player.find_by(entrant_name: entrant["name"])
        end

        if player
          # Buscar el event_seed correspondiente
          event_seed = event_seeds.find_by(player: player)

          if event_seed
            # Actualizar placement si es diferente
            if event_seed.placement != placement
              event_seed.update!(placement: placement)
              updated_count += 1
              Rails.logger.info "📊 Actualizado placement: #{player.entrant_name} - Posición #{placement}"
            end
          else
            # Crear event_seed con placement si no existe
            # Esto puede pasar si el jugador participó pero no se sincronizó en seeds
            event_seed = event_seeds.create!(
              player: player,
              seed_num: entrant["initialSeedNum"],
              placement: placement
            )
            created_count += 1
            Rails.logger.info "➕ Creado event_seed con placement: #{player.entrant_name} - Seed #{entrant["initialSeedNum"]} - Posición #{placement}"
          end
        else
          Rails.logger.warn "⚠️ No se encontró jugador para el entrant: #{entrant["name"]} (User ID: #{user["id"]})"
        end
      end

      Rails.logger.info "✅ Sincronización de placements completada para #{name}: #{updated_count} actualizados, #{created_count} creados"
      update(placements_last_synced_at: Time.current)

    rescue Faraday::ClientError => e
      retries += 1
      if e.response[:status] == 429 && retries <= max_retries
        Rails.logger.warn "Rate limit excedido para placements del evento #{name}. Reintento #{retries}/#{max_retries} en #{retry_delay} segundos..."
        sleep(retry_delay)
        retry
      else
        Rails.logger.error "Error sincronizando placements para evento #{name}: #{e.message}"
        raise
      end
    rescue StandardError => e
      Rails.logger.error "Error procesando placements para evento #{name}: #{e.message}"
      raise
    end
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
        elsif [ 404, 500 ].include?(e.response[:status])
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
      { id: 1, entrant_name: "🔺 Leoxe", name: "Leoxe", user_id: 1, twitter_handle: "leoxe_smash" },
      { id: 2, entrant_name: "🍁 Xupapapa", name: "Xupapapa", user_id: 2, twitter_handle: "xupapapa_ssbu" },
      { id: 3, entrant_name: "⬜ yeki", name: "yeki", user_id: 3, twitter_handle: "yeki_ssbu" },
      { id: 4, entrant_name: "Chayanne", name: "Chayanne", user_id: 4, twitter_handle: "chayanne_smash" },
      { id: 5, entrant_name: "Radiant", name: "Radiant", user_id: 5, twitter_handle: "radiant_ssbu" },
      { id: 6, entrant_name: "⬜ Ainwind", name: "Ainwind", user_id: 6, twitter_handle: "ainwind_smash" },
      { id: 7, entrant_name: "⬜ JajaSC", name: "JajaSC", user_id: 7, twitter_handle: "jajasc_ssbu" },
      { id: 8, entrant_name: "🔺 Buttero", name: "Buttero", user_id: 8, twitter_handle: "buttero_smash" },
      { id: 9, entrant_name: "⬜ Poiolpo-X", name: "Poiolpo-X", user_id: 9, twitter_handle: "poiolpo_x_ssbu" },
      { id: 10, entrant_name: "⬜ Gago", name: "Gago", user_id: 10, twitter_handle: "gago_ssbu" },
      { id: 11, entrant_name: "Mazon", name: "Mazon", user_id: 11, twitter_handle: "mazon_smash" },
      { id: 12, entrant_name: "⬜ secret", name: "secret", user_id: 12, twitter_handle: "secret_ssbu" },
      { id: 13, entrant_name: "⬜ marr", name: "marr", user_id: 13, twitter_handle: "marr_ssbu" },
      { id: 14, entrant_name: "⬜ Rodo", name: "Rodo", user_id: 14, twitter_handle: "rodo_smash" },
      { id: 15, entrant_name: "⬜ Hvniel07", name: "Hvniel07", user_id: 15, twitter_handle: "hvniel07_ssbu" },
      { id: 16, entrant_name: "⬜ Shaska", name: "Shaska", user_id: 16, twitter_handle: "shaska_smash" },
      { id: 17, entrant_name: "Rch23#", name: "Rch23#", user_id: 17, twitter_handle: "rch23_ssbu" },
      { id: 18, entrant_name: "⬜ Riben", name: "Riben", user_id: 18, twitter_handle: "riben_smash" },
      { id: 19, entrant_name: "⬜ Criollo110", name: "Criollo110", user_id: 19, twitter_handle: "criollo110_ssbu" },
      { id: 20, entrant_name: "Benoo110", name: "Benoo110", user_id: 20, twitter_handle: "benoo110_smash" },
      { id: 21, entrant_name: "⬜ Agusaurio", name: "Agusaurio", user_id: 21, twitter_handle: "agusaurio_ssbu" },
      { id: 22, entrant_name: "⬜ Amadeu", name: "Amadeu", user_id: 22, twitter_handle: "amadeu_smash" },
      { id: 23, entrant_name: "Disponible", name: "Disponible", user_id: 23, twitter_handle: nil },
      { id: 24, entrant_name: "Disponible", name: "Disponible", user_id: 24, twitter_handle: nil }
    ]

    players_data.each do |data|
      Player.find_or_create_by(user_id: data[:user_id]) do |p|
        p.id = data[:id]
        p.entrant_name = data[:entrant_name]
        p.name = data[:name]
        p.twitter_handle = data[:twitter_handle]
        # Removed character_stock_icon as it no longer exists in Player model
      end
    end

    (1..24).each do |seed_num|
      player = Player.find_by(id: seed_num)
      EventSeed.create(
        event: self,
        player: player,
        seed_num: seed_num,
        character_stock_icon: nil # Set to nil since Player no longer has this attribute
      )
    end
  end
end
