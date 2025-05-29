class Tournament < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :event_seeds, through: :events
  has_many :players, through: :event_seeds

  # Callback para parsear ubicación cuando se guarda o actualiza venue_address
  before_save :parse_location_from_venue_address, if: :venue_address_changed?

  # Callback para marcar como online si venue_address es "Chile"
  before_save :mark_chile_as_online, if: :venue_address_changed?

  # Callback para generar la URL de start.gg
  before_save :generate_start_gg_url, if: :slug_changed?

  scope :by_region, ->(region) { where(region: region) if region.present? }
  scope :by_city, ->(city) { where(city: city) if city.present? }

  # Scopes para torneos online
  scope :online_tournaments, -> { where(region: "Online") }
  scope :physical_tournaments, -> { where.not(region: "Online") }

  # Método para generar la URL de start.gg
  def generate_start_gg_url
    if slug.present?
      self.start_gg_url = "https://www.start.gg/#{slug}"
    end
  end

  # Método para obtener la URL de start.gg (con fallback si no está guardada)
  def start_gg_url_or_generate
    return start_gg_url if start_gg_url.present?

    if slug.present?
      "https://www.start.gg/#{slug}"
    else
      nil
    end
  end

  # Métodos para torneos online
  def online?
    region == "Online"
  end

  def physical?
    !online?
  end

  def mark_as_online!
    update_columns(city: nil, region: "Online")
  end

  # Método para detectar si debería ser online basado en nombre y venue
  def should_be_online?
    parser = LocationParserService.new

    # Verificar por venue_address
    if venue_address.present?
      location_data = parser.parse_location(venue_address)
      return location_data[:region] == "Online"
    end

    false
  end

  def fetch_and_save_events
    # Verificar si ya hay eventos para este torneo
    return if events.any?

    Rails.logger.info "Sincronizando eventos para el torneo: #{name} (Fecha: #{start_at})"
    begin
      # Crear una instancia de StartGgClient para las consultas a la API
      client = StartGgClient.new

      # Obtener eventos desde la API usando StartGgQueries
      events_data = StartGgQueries.fetch_tournament_events(client, slug)

      # Guardar cada evento en la base de datos
      events_data.each do |event_data|
        Event.find_or_create_by(tournament: self, slug: event_data["slug"]) do |event|
          event.name = event_data["name"]
          event.id = event_data["id"]
        end
        Rails.logger.info "Evento guardado: #{event_data['name']} (ID: #{event_data['id']})"
      end
    rescue Faraday::ClientError => e
      if e.response[:status] == 429
        Rails.logger.warn "Rate limit excedido para torneo #{slug}. Esperando 60 segundos..."
        sleep(60) # Espera 60 segundos antes de reintentar
        retry
      elsif [ 404, 500 ].include?(e.response[:status])
        Rails.logger.error "Error HTTP #{e.response[:status]} al obtener eventos para torneo #{slug}: #{e.response[:body]}"
        raise "Error HTTP al obtener eventos: #{e.response[:status]} - #{e.response[:body]}"
      else
        Rails.logger.error "Error al obtener eventos para torneo #{slug}: #{e.message}"
        raise
      end
    rescue StandardError => e
      Rails.logger.error "Error procesando eventos para torneo #{name}: #{e.message}"
      raise
    end
    sleep 5 # Retraso para respetar los límites de rate limiting (80 solicitudes/minuto)
  end

  def calculated_events_count
    # Accede al atributo 'events_count_data' que se seleccionó en el controlador.
    # Proporciona un fallback por si el torneo no se cargó con este select específico.
    attributes["events_count_data"] || events.size
  end

  def calculated_total_event_seeds_count
    # Accede al atributo 'total_event_seeds_count_data'.
    attributes["total_event_seeds_count_data"] || event_seeds.size # Fallback
  end

  # Método para calcular asistentes reales basado en participantes únicos de eventos de Smash
  def calculated_smash_attendees_count
    # Si ya tenemos el conteo calculado desde una consulta optimizada, usarlo
    if attributes.key?("smash_attendees_count_data")
      return attributes["smash_attendees_count_data"]
    end

    # Fallback: calcular participantes únicos de eventos de Smash válidos
    event_seeds.joins(:event)
              .where(events: { videogame_id: Event::SMASH_ULTIMATE_VIDEOGAME_ID })
              .where('events.team_max_players IS NULL OR events.team_max_players <= 1')
              .distinct
              .count(:player_id)
  end

  # Métodos optimizados para estadísticas
  def calculated_smash_attendees_count_optimized
    return @smash_attendees_cached if defined?(@smash_attendees_cached)
    @smash_attendees_cached = calculated_smash_attendees_count
  end

  def calculated_events_count_optimized
    return @events_count_cached if defined?(@events_count_cached)
    @events_count_cached = calculated_events_count
  end

  def calculated_total_event_seeds_count_optimized
    return @event_seeds_count_cached if defined?(@event_seeds_count_cached)
    @event_seeds_count_cached = calculated_total_event_seeds_count
  end

  # Método para verificar si un evento tiene seeds sin causar N+1
  def has_seeds_optimized?
    return @has_seeds_cached if defined?(@has_seeds_cached)
    @has_seeds_cached = events.any? { |event| event.event_seeds.any? }
  end

  # Método para precargar estadísticas optimizado
  def self.with_preloaded_stats
    includes(events: :event_seeds)
      .joins("LEFT JOIN events AS smash_events ON smash_events.tournament_id = tournaments.id AND smash_events.videogame_id = #{Event::SMASH_ULTIMATE_VIDEOGAME_ID} AND (smash_events.team_max_players IS NULL OR smash_events.team_max_players <= 1)")
      .joins("LEFT JOIN event_seeds AS smash_seeds ON smash_seeds.event_id = smash_events.id")
      .select("tournaments.*, 
              COUNT(DISTINCT events.id) AS events_count_data,
              COUNT(DISTINCT event_seeds.id) AS total_event_seeds_count_data,
              COUNT(DISTINCT smash_seeds.player_id) AS smash_attendees_count_data")
      .group("tournaments.id")
  end

  # Método para determinar qué conteo de asistentes usar (prioriza el calculado sobre el de la API)
  def best_attendees_count
    smash_count = calculated_smash_attendees_count_optimized
    
    # Si tenemos participantes de Smash, usar ese conteo
    if smash_count > 0
      smash_count
    else
      # Fallback al conteo de la API si no hay datos de Smash
      attendees_count
    end
  end

  # Método de clase para precargar asistentes de Smash de manera eficiente
  def self.with_smash_attendees_count
    left_joins("LEFT JOIN events AS smash_events ON smash_events.tournament_id = tournaments.id AND smash_events.videogame_id = #{Event::SMASH_ULTIMATE_VIDEOGAME_ID} AND (smash_events.team_max_players IS NULL OR smash_events.team_max_players <= 1)")
      .left_joins("LEFT JOIN event_seeds AS smash_seeds ON smash_seeds.event_id = smash_events.id")
      .select("tournaments.*, COUNT(DISTINCT smash_seeds.player_id) AS smash_attendees_count_data")
      .group("tournaments.id")
  end

  private

  def parse_location_from_venue_address
    return unless venue_address.present?

    begin
      parser = LocationParserService.new
      location_data = parser.parse_location(venue_address)

      self.city = location_data[:city] if location_data[:city].present?
      self.region = location_data[:region] if location_data[:region].present?

      Rails.logger.info "Ubicación parseada para torneo #{name}: Ciudad=#{city}, Región=#{region}"
    rescue => e
      Rails.logger.error "Error parseando ubicación para torneo #{name}: #{e.message}"
    end
  end

  def mark_chile_as_online
    if venue_address == "Chile"
      self.city = nil
      self.region = "Online"
      Rails.logger.info "Torneo #{name} marcado automáticamente como online (venue_address: 'Chile')"
    end
  end
end
