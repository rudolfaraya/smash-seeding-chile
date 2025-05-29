class PlayersFilterService
  attr_reader :params, :session

  def initialize(params, session)
    @params = params
    @session = session
  end

  def call
    filters = current_filter_params
    cache_key = cache_key_for_filters(filters)

    # CACHÉ: Intentar obtener IDs del caché primero (TODOS los IDs, no paginados)
    all_player_ids = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      Rails.logger.info "=== CACHE MISS: Generando TODOS los IDs para #{cache_key} ==="
      fetch_all_filtered_player_ids(filters)
    end

    Rails.logger.info "=== CACHE HIT: #{all_player_ids.size} IDs totales obtenidos para #{cache_key} ==="

    load_players_with_associations(all_player_ids, filters[:page].to_i)
  end

  def self.invalidate_cache
    Rails.logger.info "=== INVALIDATING PLAYERS CACHE ==="
    Rails.cache.delete_matched("players_ids_*")
  end

  private

  def current_filter_params
    {
      character_filter: params[:character_filter].presence || session[:players_character_filter],
      team_filter: params[:team_filter].presence || session[:players_team_filter],
      country_filter: params[:country_filter].presence || session[:players_country_filter],
      query: params[:query].presence || session[:players_query],
      sort_by: params[:sort_by].presence || session[:players_sort_by] || "recent_tournament",
      page: params[:page].presence || session[:players_page] || 1
    }
  end

  def cache_key_for_filters(filters)
    # No incluir 'page' en el cache key porque queremos cachear TODOS los IDs
    filter_without_page = filters.except(:page)
    "players_ids_#{Digest::MD5.hexdigest(filter_without_page.values.compact.join('_'))}"
  end

  def fetch_all_filtered_player_ids(filters)
    query = build_base_query
    query = apply_character_filter(query, filters[:character_filter])
    query = apply_team_filter(query, filters[:team_filter])
    query = apply_country_filter(query, filters[:country_filter])
    query = apply_search_filter(query, filters[:query])
    query = apply_sorting(query, filters[:sort_by])
    
    # NO aplicar paginación aquí - queremos TODOS los IDs
    query.pluck(:id)
  end

  def build_base_query
    # Usar un scope más específico para mejorar el rendimiento
    Player.joins(:event_seeds).distinct
  end

  def apply_character_filter(query, character_filter)
    return query if character_filter.blank?

    if character_filter == "none"
      query.where(
        character_1: [nil, ""],
        character_2: [nil, ""],
        character_3: [nil, ""]
      )
    else
      query.where(
        "players.character_1 = ? OR players.character_2 = ? OR players.character_3 = ?",
        character_filter, character_filter, character_filter
      )
    end
  end

  def apply_team_filter(query, team_filter)
    return query if team_filter.blank?

    if team_filter == "none"
      query.left_joins(:player_teams).where(player_teams: { id: nil })
    else
      query.joins(:player_teams).where(player_teams: { team_id: team_filter })
    end
  end

  def apply_country_filter(query, country_filter)
    return query if country_filter.blank?

    if country_filter == "none"
      query.where(players: { country: [nil, ""] })
    else
      query.where(players: { country: country_filter })
    end
  end

  def apply_search_filter(query, search_query)
    return query if search_query.blank?

    query.where(
      "LOWER(players.name) LIKE LOWER(?) OR LOWER(players.entrant_name) LIKE LOWER(?) OR LOWER(players.twitter_handle) LIKE LOWER(?)",
      "%#{search_query}%", "%#{search_query}%", "%#{search_query}%"
    )
  end

  def apply_sorting(query, sort_by)
    # Optimizar joins según el tipo de ordenamiento
    query = add_sorting_joins(query, sort_by)
    query = add_sorting_order(query, sort_by)
    query
  end

  def add_sorting_joins(query, sort_by)
    case sort_by
    when "tag_asc", "tag_desc"
      # No necesita joins adicionales para ordenamiento por nombre
      query
    when "recent_tournament", "oldest_tournament", "tournaments_count_desc", "tournaments_count_asc"
      # Necesita join con tournaments
      query.joins(event_seeds: { event: :tournament })
    when "events_count_desc", "events_count_asc"
      # Ya tiene event_seeds del build_base_query
      query
    else
      # Por defecto, necesita tournaments
      query.joins(event_seeds: { event: :tournament })
    end
  end

  def add_sorting_order(query, sort_by)
    case sort_by
    when "tag_asc"
      query.order(Arel.sql("LOWER(COALESCE(players.entrant_name, '')) ASC"))
    when "tag_desc"
      query.order(Arel.sql("LOWER(COALESCE(players.entrant_name, '')) DESC"))
    when "recent_tournament"
      query.group("players.id")
           .order(Arel.sql("MAX(tournaments.start_at) DESC"))
    when "oldest_tournament"
      query.group("players.id")
           .order(Arel.sql("MAX(tournaments.start_at) ASC"))
    when "events_count_desc"
      query.group("players.id")
           .order(Arel.sql("COUNT(event_seeds.id) DESC, LOWER(COALESCE(players.entrant_name, '')) ASC"))
    when "events_count_asc"
      query.group("players.id")
           .order(Arel.sql("COUNT(event_seeds.id) ASC, LOWER(COALESCE(players.entrant_name, '')) ASC"))
    when "tournaments_count_desc"
      query.group("players.id")
           .order(Arel.sql("COUNT(DISTINCT tournaments.id) DESC, LOWER(COALESCE(players.entrant_name, '')) ASC"))
    when "tournaments_count_asc"
      query.group("players.id")
           .order(Arel.sql("COUNT(DISTINCT tournaments.id) ASC, LOWER(COALESCE(players.entrant_name, '')) ASC"))
    else
      # Por defecto: más reciente inscripción
      query.group("players.id")
           .order(Arel.sql("MAX(tournaments.start_at) DESC"))
    end
  end

  def load_players_with_associations(all_player_ids, page)
    return Kaminari.paginate_array([]).page(1).per(50) if all_player_ids.empty?

    total_count = all_player_ids.size
    
    # Aplicar paginación a los IDs
    per_page = 50
    offset = (page - 1) * per_page
    paged_ids = all_player_ids[offset, per_page] || []

    Rails.logger.info "=== Paginación: página #{page}, total #{total_count}, mostrando #{paged_ids.size} ==="

    if paged_ids.empty?
      return Kaminari.paginate_array([], total_count: total_count).page(page).per(per_page)
    end

    # Cargar con eager loading optimizado y preservar orden
    players = Player.includes(
      event_seeds: { event: :tournament },
      player_teams: :team
    ).where(id: paged_ids)

    # Preservar el orden usando un hash
    players_hash = players.index_by(&:id)
    ordered_players = paged_ids.map { |id| players_hash[id] }.compact

    # Usar Kaminari para simular paginación con el total correcto
    Kaminari.paginate_array(ordered_players, total_count: total_count).page(page).per(per_page)
  end
end 