class Team < ApplicationRecord
  has_many :player_teams, dependent: :destroy
  has_many :players, through: :player_teams

  # Active Storage para el logo
  has_one_attached :logo_image

  validates :name, presence: true, uniqueness: true
  validates :acronym, presence: true, uniqueness: true, length: { in: 2..5 }
  validates :description, length: { maximum: 500 }

  # Validación para el logo
  validate :logo_image_format, if: -> { logo_image.attached? }

  scope :with_players_count, -> {
    left_joins(:player_teams)
      .select("teams.*, COUNT(player_teams.id) AS players_count_data")
      .group("teams.id")
  }

  def players_count
    if attributes.key?("players_count_data")
      attributes["players_count_data"]
    else
      player_teams.count
    end
  end

  def primary_players
    players.joins(:player_teams).where(player_teams: { is_primary: true })
  end

  def display_name
    "#{name} (#{acronym})"
  end

  def logo_or_acronym
    if logo_image.attached?
      logo_image
    elsif logo.present?
      logo
    else
      acronym
    end
  end

  # Método para obtener jugadores con información de si es equipo principal
  def players_with_primary_info
    Player.joins(:player_teams)
          .select("players.*, player_teams.is_primary AS is_primary")
          .where(player_teams: { team_id: id })
          .order("player_teams.is_primary DESC, players.entrant_name ASC")
  end

  # Método para obtener jugadores con estadísticas completas
  def players_with_stats
    players_data = Player.joins(:player_teams)
                        .left_joins(:event_seeds)
                        .left_joins(event_seeds: { event: :tournament })
                        .select(
                          "players.*",
                          "player_teams.is_primary",
                          "COUNT(DISTINCT events.id) as events_count",
                          "COUNT(DISTINCT tournaments.id) as tournaments_count"
                        )
                        .where(player_teams: { team_id: id })
                        .group("players.id, player_teams.is_primary")
                        .order("player_teams.is_primary DESC, players.entrant_name ASC")

    # Convertir a hash para facilitar el acceso en las vistas
    players_data.map do |player|
      {
        id: player.id,
        name: player.name,
        entrant_name: player.entrant_name,
        is_primary: player.is_primary ? 1 : 0,
        events_count: player.events_count || 0,
        tournaments_count: player.tournaments_count || 0
      }
    end
  end

  # Agregar un jugador al equipo
  def add_player(player_id, is_primary = false)
    return false if player_id.blank?

    player = Player.find_by(id: player_id)
    return false unless player

    # Usar una transacción para asegurar consistencia
    ActiveRecord::Base.transaction do
      # Si va a ser principal para este jugador, desmarcar otros equipos como principales PRIMERO
      if is_primary
        player.player_teams.where(is_primary: true).update_all(is_primary: false)
      end

      # Verificar si ya existe la relación
      existing = player_teams.find_by(player_id: player_id)
      if existing
        existing.update!(is_primary: is_primary)
      else
        player_teams.create!(player_id: player_id, is_primary: is_primary)
      end
    end

    true
  rescue => e
    Rails.logger.error "Error agregando jugador #{player_id} al equipo #{id}: #{e.message}"
    false
  end

  # Remover un jugador del equipo
  def remove_player(player_id)
    return false if player_id.blank?

    removed = player_teams.where(player_id: player_id).destroy_all
    removed.any?
  rescue => e
    Rails.logger.error "Error removiendo jugador #{player_id} del equipo #{id}: #{e.message}"
    false
  end

  # Buscar jugadores que no están en este equipo
  def available_players(search_term = nil)
    excluded_player_ids = player_teams.pluck(:player_id)

    query = Player.where.not(id: excluded_player_ids)

    if search_term.present?
      # Usar sintaxis más simple compatible con SQLite
      search_term_safe = search_term.downcase
      query = query.where(
        "LOWER(name) LIKE :search OR LOWER(entrant_name) LIKE :search",
        search: "%#{search_term_safe}%"
      )
    end

    query.order(:entrant_name).limit(20)
  end

  private

  def logo_image_format
    return unless logo_image.attached?

    unless logo_image.content_type.in?([ "image/jpeg", "image/png", "image/gif", "image/webp" ])
      errors.add(:logo_image, "debe ser un archivo de imagen válido (JPEG, PNG, GIF, WebP)")
    end

    if logo_image.byte_size > 5.megabytes
      errors.add(:logo_image, "debe ser menor a 5MB")
    end

    # Verificar que sea aproximadamente cuadrada
    if logo_image.attached? && logo_image.representable?
      metadata = logo_image.metadata
      if metadata[:width] && metadata[:height]
        aspect_ratio = metadata[:width].to_f / metadata[:height].to_f
        unless (0.8..1.25).include?(aspect_ratio)
          errors.add(:logo_image, "debe ser aproximadamente cuadrada (relación de aspecto entre 0.8 y 1.25)")
        end
      end
    end
  end
end
