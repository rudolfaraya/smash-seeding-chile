class Player < ApplicationRecord
  has_many :event_seeds, dependent: :destroy
  has_many :events, through: :event_seeds
  has_many :tournaments, through: :events
  
  validates :name, presence: true, on: :create
  validates :entrant_name, presence: true
  validates :user_id, presence: true, uniqueness: true
  validates :discriminator, presence: true, on: :create

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
    'mario' => 'Mario',
    'donkey_kong' => 'Donkey Kong',
    'link' => 'Link',
    'samus' => 'Samus',
    'dark_samus' => 'Dark Samus',
    'yoshi' => 'Yoshi',
    'kirby' => 'Kirby',
    'fox' => 'Fox',
    'pikachu' => 'Pikachu',
    'luigi' => 'Luigi',
    'ness' => 'Ness',
    'captain_falcon' => 'Captain Falcon',
    'jigglypuff' => 'Jigglypuff',
    'peach' => 'Peach',
    'daisy' => 'Daisy',
    'bowser' => 'Bowser',
    'ice_climbers' => 'Ice Climbers',
    'sheik' => 'Sheik',
    'zelda' => 'Zelda',
    'dr_mario' => 'Dr. Mario',
    'pichu' => 'Pichu',
    'falco' => 'Falco',
    'marth' => 'Marth',
    'lucina' => 'Lucina',
    'young_link' => 'Young Link',
    'ganondorf' => 'Ganondorf',
    'mewtwo' => 'Mewtwo',
    'roy' => 'Roy',
    'chrom' => 'Chrom',
    'mr_game_and_watch' => 'Mr. Game & Watch',
    'meta_knight' => 'Meta Knight',
    'pit' => 'Pit',
    'dark_pit' => 'Dark Pit',
    'zero_suit_samus' => 'Zero Suit Samus',
    'wario' => 'Wario',
    'snake' => 'Snake',
    'ike' => 'Ike',
    'pokemon_trainer' => 'Pokémon Trainer',
    'diddy_kong' => 'Diddy Kong',
    'lucas' => 'Lucas',
    'sonic' => 'Sonic',
    'king_dedede' => 'King Dedede',
    'olimar' => 'Olimar',
    'lucario' => 'Lucario',
    'rob' => 'R.O.B.',
    'toon_link' => 'Toon Link',
    'wolf' => 'Wolf',
    'villager' => 'Villager',
    'mega_man' => 'Mega Man',
    'wii_fit_trainer' => 'Wii Fit Trainer',
    'rosalina_luma' => 'Rosalina & Luma',
    'little_mac' => 'Little Mac',
    'greninja' => 'Greninja',
    'palutena' => 'Palutena',
    'pac_man' => 'Pac-Man',
    'robin' => 'Robin',
    'shulk' => 'Shulk',
    'bowser_jr' => 'Bowser Jr.',
    'duck_hunt' => 'Duck Hunt',
    'ryu' => 'Ryu',
    'ken' => 'Ken',
    'cloud' => 'Cloud',
    'corrin' => 'Corrin',
    'bayonetta' => 'Bayonetta',
    'inkling' => 'Inkling',
    'ridley' => 'Ridley',
    'simon' => 'Simon',
    'richter' => 'Richter',
    'king_k_rool' => 'King K. Rool',
    'isabelle' => 'Isabelle',
    'incineroar' => 'Incineroar',
    'piranha_plant' => 'Piranha Plant',
    'joker' => 'Joker',
    'hero' => 'Hero',
    'banjo_kazooie' => 'Banjo & Kazooie',
    'terry' => 'Terry',
    'byleth' => 'Byleth',
    'min_min' => 'Min Min',
    'steve' => 'Steve',
    'sephiroth' => 'Sephiroth',
    'pyra_mythra' => 'Pyra/Mythra',
    'kazuya' => 'Kazuya',
    'sora' => 'Sora',
    'mii_brawler' => 'Mii Brawler',
    'mii_swordfighter' => 'Mii Swordfighter',
    'mii_gunner' => 'Mii Gunner'
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
