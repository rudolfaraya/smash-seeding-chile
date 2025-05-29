class Player < ApplicationRecord
  has_many :event_seeds, dependent: :destroy
  has_many :events, through: :event_seeds
  has_many :tournaments, through: :events

  # Relaciones con equipos
  has_many :player_teams, dependent: :destroy
  has_many :teams, through: :player_teams

  validates :name, presence: true, on: :create
  validates :entrant_name, presence: true
  
  # Un jugador debe tener o user_id (con cuenta) o start_gg_id (sin cuenta)
  validates :user_id, uniqueness: true, allow_nil: true
  validates :start_gg_id, uniqueness: true, allow_nil: true
  validate :must_have_user_id_or_start_gg_id
  
  validates :discriminator, presence: true, on: :create, if: :user_id?

  # Validaciones para personajes de Smash
  validates :skin_1, inclusion: { in: 1..8 }, allow_nil: true
  validates :skin_2, inclusion: { in: 1..8 }, allow_nil: true
  validates :skin_3, inclusion: { in: 1..8 }, allow_nil: true

  # Scopes
  scope :search, ->(query) {
    where("LOWER(entrant_name) LIKE LOWER(?) OR LOWER(name) LIKE LOWER(?)", "%#{query}%", "%#{query}%") if query.present?
  }

  # Constante con todos los personajes de Smash Ultimate
  SMASH_CHARACTERS = {
    "mario" => "Mario",
    "donkey_kong" => "Donkey Kong",
    "link" => "Link",
    "samus" => "Samus",
    "dark_samus" => "Dark Samus",
    "yoshi" => "Yoshi",
    "kirby" => "Kirby",
    "fox" => "Fox",
    "pikachu" => "Pikachu",
    "luigi" => "Luigi",
    "ness" => "Ness",
    "captain_falcon" => "Captain Falcon",
    "jigglypuff" => "Jigglypuff",
    "peach" => "Peach",
    "daisy" => "Daisy",
    "bowser" => "Bowser",
    "ice_climbers" => "Ice Climbers",
    "sheik" => "Sheik",
    "zelda" => "Zelda",
    "dr_mario" => "Dr. Mario",
    "pichu" => "Pichu",
    "falco" => "Falco",
    "marth" => "Marth",
    "lucina" => "Lucina",
    "young_link" => "Young Link",
    "ganondorf" => "Ganondorf",
    "mewtwo" => "Mewtwo",
    "roy" => "Roy",
    "chrom" => "Chrom",
    "mr_game_and_watch" => "Mr. Game & Watch",
    "meta_knight" => "Meta Knight",
    "pit" => "Pit",
    "dark_pit" => "Dark Pit",
    "zero_suit_samus" => "Zero Suit Samus",
    "wario" => "Wario",
    "snake" => "Snake",
    "ike" => "Ike",
    "pokemon_trainer" => "Pokémon Trainer",
    "diddy_kong" => "Diddy Kong",
    "lucas" => "Lucas",
    "sonic" => "Sonic",
    "king_dedede" => "King Dedede",
    "olimar" => "Olimar",
    "lucario" => "Lucario",
    "rob" => "R.O.B.",
    "toon_link" => "Toon Link",
    "wolf" => "Wolf",
    "villager" => "Villager",
    "mega_man" => "Mega Man",
    "wii_fit_trainer" => "Wii Fit Trainer",
    "rosalina_luma" => "Rosalina & Luma",
    "little_mac" => "Little Mac",
    "greninja" => "Greninja",
    "palutena" => "Palutena",
    "pac_man" => "Pac-Man",
    "robin" => "Robin",
    "shulk" => "Shulk",
    "bowser_jr" => "Bowser Jr.",
    "duck_hunt" => "Duck Hunt",
    "ryu" => "Ryu",
    "ken" => "Ken",
    "cloud" => "Cloud",
    "corrin" => "Corrin",
    "bayonetta" => "Bayonetta",
    "inkling" => "Inkling",
    "ridley" => "Ridley",
    "simon" => "Simon",
    "richter" => "Richter",
    "king_k_rool" => "King K. Rool",
    "isabelle" => "Isabelle",
    "incineroar" => "Incineroar",
    "piranha_plant" => "Piranha Plant",
    "joker" => "Joker",
    "hero" => "Hero",
    "banjo_kazooie" => "Banjo & Kazooie",
    "terry" => "Terry",
    "byleth" => "Byleth",
    "min_min" => "Min Min",
    "steve" => "Steve",
    "sephiroth" => "Sephiroth",
    "pyra_mythra" => "Pyra/Mythra",
    "kazuya" => "Kazuya",
    "sora" => "Sora",
    "mii_brawler" => "Mii Brawler",
    "mii_swordfighter" => "Mii Swordfighter",
    "mii_gunner" => "Mii Gunner"
  }.freeze

  # Personajes que no tienen skins (solo tienen una imagen)
  CHARACTERS_WITHOUT_SKINS = %w[mii_brawler mii_swordfighter mii_gunner].freeze

  def smash_characters
    [
      character_1.present? ? { character: character_1, skin: skin_1 } : nil,
      character_2.present? ? { character: character_2, skin: skin_2 } : nil,
      character_3.present? ? { character: character_3, skin: skin_3 } : nil
    ].compact
  end

  def character_display_name(character_key)
    return "Sin personaje seleccionado" if character_key.blank?
    SMASH_CHARACTERS[character_key] || character_key.humanize
  end

  # Método seguro para asignar gender_pronoun/gender_pronoum dependiendo de qué columna exista
  def assign_gender_pronoun(value)
    column_name = self.class.column_names.include?("gender_pronoun") ? "gender_pronoun" : "gender_pronoum"
    self[column_name] = value
  end

  # Generar enlace a Twitter/X
  def twitter_url
    return nil unless twitter_handle.present?
    "https://x.com/#{twitter_handle}"
  end

  # Generar enlace al perfil de start.gg
  def start_gg_url
    return nil unless discriminator.present?
    "https://start.gg/user/#{discriminator}"
  end

  # Actualizar información del jugador desde la API de start.gg
  def update_from_start_gg_api
    return false unless user_id.present?

    Rails.logger.info "🔍 Actualizando información del jugador #{entrant_name} (User ID: #{user_id}) desde start.gg"

    begin
      client = StartGgClient.new
      Rails.logger.info "🌐 Cliente de start.gg creado exitosamente"

      # Obtener información básica del usuario
      user_data = StartGgQueries.fetch_user_by_id(client, user_id)
      Rails.logger.info "📡 Respuesta de API recibida para usuario #{user_id}: #{user_data.present? ? 'Datos encontrados' : 'Sin datos'}"

      # Obtener tag más reciente del usuario
      recent_tag = StartGgQueries.fetch_user_recent_tag(client, user_id)
      Rails.logger.info "🏷️ Tag reciente obtenido: #{recent_tag || 'No encontrado'}"

      if user_data.present?
        Rails.logger.info "📝 Actualizando atributos para #{entrant_name}"
        result = update_attributes_from_api_data(user_data, recent_tag)
        if result
          Rails.logger.info "✅ Información actualizada exitosamente para #{entrant_name}"
          true
        else
          Rails.logger.error "❌ Error actualizando atributos para #{entrant_name}"
          false
        end
      else
        Rails.logger.warn "⚠️ No se encontró información para el usuario #{user_id} (#{entrant_name})"
        false
      end
    rescue StandardError => e
      Rails.logger.error "❌ Error actualizando jugador #{entrant_name}: #{e.message}"
      Rails.logger.error "🔍 Backtrace: #{e.backtrace.first(5).join(', ')}"
      false
    end
  end

  # Verificar si la información del jugador necesita actualización
  def needs_update?
    # Considerar que necesita actualización si:
    # - No tiene nombre completo
    # - No tiene información de ubicación
    # - No se ha actualizado en los últimos 30 días
    name.blank? ||
    country.blank? ||
    updated_at < 30.days.ago
  end

  # Marcar como actualizado recientemente
  def mark_as_recently_updated
    touch(:updated_at)
  end

  # Validación personalizada para requerir al menos uno de los identificadores
  def must_have_user_id_or_start_gg_id
    if user_id.nil? && start_gg_id.nil?
      errors.add(:base, "Debe tener o user_id (con cuenta) o start_gg_id (sin cuenta)")
    end
  end

  # Determinar si el jugador tiene cuenta de start.gg
  def has_start_gg_account?
    user_id.present?
  end

  # Obtener el identificador principal para búsquedas
  def primary_identifier
    user_id || start_gg_id
  end

  # Métodos para equipos
  def primary_team
    teams.joins(:player_teams).where(player_teams: { is_primary: true }).first
  end

  # Versión optimizada que usa includes para evitar N+1
  def primary_team_optimized
    return @primary_team_cached if defined?(@primary_team_cached)
    @primary_team_cached = player_teams.includes(:team).find { |pt| pt.is_primary }&.team
  end

  def secondary_teams
    teams.joins(:player_teams).where(player_teams: { is_primary: false })
  end

  def team_display
    primary = primary_team_optimized
    return "Sin equipo" unless primary
    
    if primary.logo.present?
      primary.logo
    else
      primary.acronym
    end
  end

  def team_name_display
    primary = primary_team_optimized
    return "Sin equipo" unless primary
    primary.display_name
  end

  def has_team?
    primary_team_optimized.present?
  end

  # Asignar equipos a un jugador con uno principal
  def assign_teams(team_ids, primary_team_id = nil)
    # Limpiar equipos actuales siempre
    player_teams.destroy_all

    # Si no hay equipos para asignar, simplemente retornar true (equipos limpiados)
    return true if team_ids.blank?

    # Asignar nuevos equipos
    team_ids.each do |team_id|
      next if team_id.blank?
      
      is_primary = (team_id.to_s == primary_team_id.to_s)
      player_teams.create!(
        team_id: team_id,
        is_primary: is_primary
      )
    end

    # Si no se especificó un equipo principal, hacer principal al primero
    if primary_team_id.blank? && team_ids.any?
      first_team = player_teams.first
      first_team&.update!(is_primary: true)
    end

    true
  rescue => e
    Rails.logger.error "Error asignando equipos a jugador #{id}: #{e.message}"
    false
  end

  # Agregar un equipo específico
  def add_team(team_id, is_primary = false)
    return false if team_id.blank?

    # Si va a ser principal, desmarcar otros como principales
    if is_primary
      player_teams.where(is_primary: true).update_all(is_primary: false)
    end

    # Verificar si ya existe la relación
    existing = player_teams.find_by(team_id: team_id)
    if existing
      existing.update!(is_primary: is_primary)
    else
      player_teams.create!(team_id: team_id, is_primary: is_primary)
    end

    true
  rescue => e
    Rails.logger.error "Error agregando equipo #{team_id} a jugador #{id}: #{e.message}"
    false
  end

  # Remover un equipo específico
  def remove_team(team_id)
    return false if team_id.blank?

    removed = player_teams.where(team_id: team_id).destroy_all
    
    # Si se removió el equipo principal, hacer principal al primer equipo restante
    if removed.any? { |pt| pt.is_primary? } && player_teams.any?
      player_teams.first.update!(is_primary: true)
    end

    true
  rescue => e
    Rails.logger.error "Error removiendo equipo #{team_id} de jugador #{id}: #{e.message}"
    false
  end

  # Obtener información de equipos para formularios
  def teams_for_form
    player_teams.includes(:team).map do |pt|
      {
        team_id: pt.team_id,
        team_name: pt.team.name,
        team_acronym: pt.team.acronym,
        team_logo: pt.team.logo,
        is_primary: pt.is_primary?
      }
    end
  end

  # Métodos optimizados para estadísticas
  def events_count
    return @events_count_cached if defined?(@events_count_cached)
    @events_count_cached = event_seeds.size
  end

  def tournaments_count
    return @tournaments_count_cached if defined?(@tournaments_count_cached)
    @tournaments_count_cached = events.includes(:tournament).map(&:tournament).uniq.size
  end

  def recent_tournament
    return @recent_tournament_cached if defined?(@recent_tournament_cached)
    @recent_tournament_cached = events.includes(:tournament).map(&:tournament).max_by(&:start_at)
  end

  def recent_tournament_name
    recent_tournament&.name
  end

  # Método para pre-cargar estadísticas optimizado
  def self.with_preloaded_stats
    includes(
      event_seeds: { event: :tournament },
      player_teams: :team
    )
  end

  # Scope para filtros optimizados
  scope :by_character, ->(character) {
    where("character_1 = ? OR character_2 = ? OR character_3 = ?", character, character, character) if character.present?
  }

  scope :by_team, ->(team_id) {
    joins(:player_teams).where(player_teams: { team_id: team_id }) if team_id.present?
  }

  scope :by_country, ->(country) {
    where(country: country) if country.present?
  }

  scope :with_event_seeds, -> {
    joins(:event_seeds).distinct
  }

  scope :search_optimized, ->(query) {
    where(
      "LOWER(players.name) LIKE LOWER(?) OR LOWER(players.entrant_name) LIKE LOWER(?) OR LOWER(players.twitter_handle) LIKE LOWER(?)",
      "%#{query}%", "%#{query}%", "%#{query}%"
    ) if query.present?
  }

  private

  def update_attributes_from_api_data(user_data, recent_tag = nil)
    # Preparar atributos para actualizar
    update_attrs = {}

    # Información básica
    update_attrs[:name] = user_data["name"] if user_data["name"].present?
    update_attrs[:discriminator] = user_data["discriminator"] if user_data["discriminator"].present?
    update_attrs[:bio] = user_data["bio"] if user_data["bio"].present?
    update_attrs[:birthday] = user_data["birthday"] if user_data["birthday"].present?

    # Actualizar entrant_name si se encontró un tag reciente
    if recent_tag.present?
      update_attrs[:entrant_name] = recent_tag
      Rails.logger.info "🏷️ Actualizando entrant_name de '#{entrant_name}' a '#{recent_tag}'"
    end

    # Información de ubicación
    if user_data["location"].present?
      location = user_data["location"]
      update_attrs[:city] = location["city"] if location["city"].present?
      update_attrs[:state] = location["state"] if location["state"].present?
      update_attrs[:country] = location["country"] if location["country"].present?
    end

    # Twitter handle
    if user_data["authorizations"].present?
      twitter_auth = user_data["authorizations"].find { |auth| auth["type"] == "TWITTER" }
      update_attrs[:twitter_handle] = twitter_auth["externalUsername"] if twitter_auth&.dig("externalUsername").present?
    end

    # Actualizar atributos si hay cambios
    if update_attrs.any?
      Rails.logger.info "Actualizando atributos: #{update_attrs.keys.join(', ')}"
      unless update(update_attrs)
        Rails.logger.error "Error actualizando atributos: #{errors.full_messages.join(', ')}"
        return false
      end
    end

    # Manejar pronombre de género por separado
    if user_data["genderPronoun"].present?
      assign_gender_pronoun(user_data["genderPronoun"])
      if changed?
        unless save
          Rails.logger.error "Error guardando pronombre de género: #{errors.full_messages.join(', ')}"
          return false
        end
      end
    end

    true
  end
end
