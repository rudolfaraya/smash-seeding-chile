module PlayersPerformanceHelper
  # Cache para imágenes de personajes (24 horas)
  def cached_smash_character_icon(character, skin = 1, size: :medium)
    return nil if character.blank?
    
    cache_key = "character_icon_#{character}_#{skin}_#{size}"
    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      smash_character_icon(character, skin, size: size)
    end
  end

  # Cache para avatares de personajes principales (1 hora)
  def cached_player_main_character_avatar(player, size: :medium)
    cache_key = "player_avatar_#{player.id}_#{player.updated_at.to_i}_#{size}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      player_main_character_avatar(player, size: size)
    end
  end

  # Cache para logos de equipos (2 horas)
  def cached_team_logo(team, size: :small)
    return nil if team.blank?
    
    cache_key = "team_logo_#{team.id}_#{team.updated_at.to_i}_#{size}"
    Rails.cache.fetch(cache_key, expires_in: 2.hours) do
      team_logo_helper(team, size)
    end
  end

  # Estadísticas pre-calculadas para jugadores
  def cached_player_stats(player)
    cache_key = "player_stats_#{player.id}_#{player.updated_at.to_i}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      calculate_player_stats(player)
    end
  end

  # Pre-cargar y cachear múltiples estadísticas de jugadores
  def bulk_cache_player_stats(players)
    return {} if players.empty?

    # Obtener IDs de jugadores
    player_ids = players.map(&:id)
    
    # Cache key para estadísticas en bulk
    cache_key = "bulk_player_stats_#{Digest::MD5.hexdigest(player_ids.sort.join('_'))}"
    
    Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      # Pre-cargar todas las asociaciones necesarias
      preloaded_players = Player.includes(
        event_seeds: { event: :tournament },
        player_teams: :team
      ).where(id: player_ids)

      # Calcular estadísticas en batch
      stats_hash = {}
      preloaded_players.each do |player|
        stats_hash[player.id] = {
          events_count: player.event_seeds.size,
          tournaments_count: player.events.map(&:tournament).uniq.size,
          recent_tournament: player.events.map(&:tournament).max_by(&:start_at)&.name,
          primary_team: player.player_teams.find { |pt| pt.is_primary }&.team
        }
      end
      
      stats_hash
    end
  end

  private

  def team_logo_helper(team, size)
    if team.logo_image.attached?
      case size
      when :small
        image_tag team.logo_image, alt: team.name, class: "h-6 w-6 rounded", loading: "lazy"
      when :medium
        image_tag team.logo_image, alt: team.name, class: "h-8 w-8 rounded", loading: "lazy"
      else
        image_tag team.logo_image, alt: team.name, class: "h-10 w-10 rounded", loading: "lazy"
      end
    elsif team.logo.present?
      case size
      when :small
        team.logo.html_safe
      else
        team.logo.html_safe
      end
    else
      content_tag :span, team.acronym, class: "inline-flex items-center justify-center h-8 w-8 rounded bg-blue-600 text-white text-xs font-medium"
    end
  end

  def calculate_player_stats(player)
    {
      events_count: player.event_seeds.size,
      tournaments_count: player.events.includes(:tournament).map(&:tournament).uniq.size,
      recent_tournament: player.events.includes(:tournament).map(&:tournament).max_by(&:start_at)&.name,
      primary_team: player.player_teams.find { |pt| pt.is_primary }&.team
    }
  end

  # Invalidar cachés relacionados con un jugador específico
  def invalidate_player_caches(player_id)
    Rails.cache.delete_matched("player_avatar_#{player_id}_*")
    Rails.cache.delete_matched("player_stats_#{player_id}_*")
    Rails.cache.delete_matched("bulk_player_stats_*")
  end

  # Invalidar cachés relacionados con equipos
  def invalidate_team_caches(team_id)
    Rails.cache.delete_matched("team_logo_#{team_id}_*")
    Rails.cache.delete_matched("bulk_player_stats_*")
  end
end 