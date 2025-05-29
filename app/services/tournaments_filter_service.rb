class TournamentsFilterService
  attr_reader :params, :session

  def initialize(params, session)
    @params = params
    @session = session
  end

  def call
    filters = current_filter_params
    cache_key = cache_key_for_filters(filters)

    # CACHÉ: Intentar obtener IDs del caché primero (TODOS los IDs, no paginados)
    all_tournament_ids = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      Rails.logger.info "=== CACHE MISS: Generando TODOS los IDs de torneos para #{cache_key} ==="
      fetch_all_filtered_tournament_ids(filters)
    end

    Rails.logger.info "=== CACHE HIT: #{all_tournament_ids.size} IDs de torneos totales obtenidos para #{cache_key} ==="

    load_tournaments_with_associations(all_tournament_ids, filters[:page].to_i)
  end

  def self.invalidate_cache
    Rails.logger.info "=== INVALIDATING TOURNAMENTS CACHE ==="
    Rails.cache.delete_matched("tournaments_ids_*")
  end

  private

  def current_filter_params
    {
      query: params[:query].presence || session[:tournaments_query],
      region: params[:region].presence || session[:tournaments_region],
      city: params[:city].presence || session[:tournaments_city],
      status: params[:status].presence || session[:tournaments_status],
      start_date: params[:start_date].presence || session[:tournaments_start_date],
      end_date: params[:end_date].presence || session[:tournaments_end_date],
      sort: params[:sort].presence || session[:tournaments_sort] || "newest",
      page: params[:page].presence || session[:tournaments_page] || 1
    }
  end

  def cache_key_for_filters(filters)
    # No incluir 'page' en el cache key porque queremos cachear TODOS los IDs
    filter_without_page = filters.except(:page)
    "tournaments_ids_#{Digest::MD5.hexdigest(filter_without_page.values.compact.join('_'))}"
  end

  def fetch_all_filtered_tournament_ids(filters)
    query = build_base_query
    query = apply_search_filter(query, filters[:query])
    query = apply_region_filter(query, filters[:region])
    query = apply_city_filter(query, filters[:city])
    query = apply_status_filter(query, filters[:status])
    query = apply_date_filters(query, filters[:start_date], filters[:end_date])
    query = apply_sorting(query, filters[:sort])
    
    # NO aplicar paginación aquí - queremos TODOS los IDs
    query.pluck(:id)
  end

  def build_base_query
    # Query base optimizada con pre-carga para estadísticas
    Tournament.distinct
  end

  def apply_search_filter(query, search_query)
    return query if search_query.blank?

    query.where("LOWER(tournaments.name) LIKE LOWER(?)", "%#{search_query}%")
  end

  def apply_region_filter(query, region_filter)
    return query if region_filter.blank?

    query.where(region: region_filter)
  end

  def apply_city_filter(query, city_filter)
    return query if city_filter.blank?

    query.where(city: city_filter)
  end

  def apply_status_filter(query, status_filter)
    return query if status_filter.blank?

    case status_filter
    when "upcoming"
      query.where("start_at > ?", Time.current)
    when "past"
      query.where("start_at <= ?", Time.current)
    else
      query
    end
  end

  def apply_date_filters(query, start_date_filter, end_date_filter)
    if start_date_filter.present?
      begin
        start_date = Date.parse(start_date_filter)
        query = query.where("start_at >= ?", start_date.beginning_of_day)
      rescue Date::Error
        # Ignorar fecha inválida
      end
    end

    if end_date_filter.present?
      begin
        end_date = Date.parse(end_date_filter)
        query = query.where("start_at <= ?", end_date.end_of_day)
      rescue Date::Error
        # Ignorar fecha inválida
      end
    end

    query
  end

  def apply_sorting(query, sort_filter)
    # Optimizar joins según el tipo de ordenamiento
    query = add_sorting_joins(query, sort_filter)
    query = add_sorting_order(query, sort_filter)
    query
  end

  def add_sorting_joins(query, sort_filter)
    case sort_filter
    when "most_attendees", "least_attendees"
      # Para ordenamiento por asistentes, necesita joins con events y event_seeds de Smash
      query.joins("LEFT JOIN events AS smash_events ON smash_events.tournament_id = tournaments.id AND smash_events.videogame_id = #{Event::SMASH_ULTIMATE_VIDEOGAME_ID} AND (smash_events.team_max_players IS NULL OR smash_events.team_max_players <= 1)")
           .joins("LEFT JOIN event_seeds AS smash_seeds ON smash_seeds.event_id = smash_events.id")
    else
      # Para otros ordenamientos no necesita joins adicionales
      query
    end
  end

  def add_sorting_order(query, sort_filter)
    case sort_filter
    when "newest"
      query.order(start_at: :desc)
    when "oldest"
      query.order(start_at: :asc)
    when "most_attendees"
      query.group("tournaments.id")
           .order(Arel.sql("COUNT(DISTINCT smash_seeds.player_id) DESC, tournaments.start_at DESC"))
    when "least_attendees"
      query.group("tournaments.id")
           .order(Arel.sql("COUNT(DISTINCT smash_seeds.player_id) ASC, tournaments.start_at DESC"))
    when "alphabetical_az"
      query.order(Arel.sql("LOWER(tournaments.name) ASC"))
    when "alphabetical_za"
      query.order(Arel.sql("LOWER(tournaments.name) DESC"))
    else
      # Por defecto: más nuevos
      query.order(start_at: :desc)
    end
  end

  def load_tournaments_with_associations(all_tournament_ids, page)
    return Kaminari.paginate_array([]).page(1).per(100) if all_tournament_ids.empty?

    total_count = all_tournament_ids.size
    
    # Aplicar paginación a los IDs
    per_page = 100
    offset = (page - 1) * per_page
    paged_ids = all_tournament_ids[offset, per_page] || []

    Rails.logger.info "=== Paginación torneos: página #{page}, total #{total_count}, mostrando #{paged_ids.size} ==="

    if paged_ids.empty?
      return Kaminari.paginate_array([], total_count: total_count).page(page).per(per_page)
    end

    # Cargar con eager loading optimizado y cálculo de estadísticas en SQL
    tournaments = Tournament.includes(events: :event_seeds)
                           .joins("LEFT JOIN events ON events.tournament_id = tournaments.id")
                           .joins("LEFT JOIN event_seeds ON event_seeds.event_id = events.id")
                           .joins("LEFT JOIN events AS smash_events ON smash_events.tournament_id = tournaments.id AND smash_events.videogame_id = #{Event::SMASH_ULTIMATE_VIDEOGAME_ID} AND (smash_events.team_max_players IS NULL OR smash_events.team_max_players <= 1)")
                           .joins("LEFT JOIN event_seeds AS smash_seeds ON smash_seeds.event_id = smash_events.id")
                           .select("tournaments.*, 
                                   COUNT(DISTINCT events.id) AS events_count_data,
                                   COUNT(DISTINCT event_seeds.id) AS total_event_seeds_count_data,
                                   COUNT(DISTINCT smash_seeds.player_id) AS smash_attendees_count_data")
                           .where(id: paged_ids)
                           .group("tournaments.id")

    # Preservar el orden usando un hash
    tournaments_hash = tournaments.index_by(&:id)
    ordered_tournaments = paged_ids.map { |id| tournaments_hash[id] }.compact

    # Usar Kaminari para simular paginación con el total correcto
    Kaminari.paginate_array(ordered_tournaments, total_count: total_count).page(page).per(per_page)
  end
end 