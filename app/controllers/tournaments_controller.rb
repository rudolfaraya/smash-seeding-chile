class TournamentsController < ApplicationController
  def index
    # Si no hay parámetros de filtros, limpiar la sesión (clear all)
    if params[:query].nil? && params[:region].nil? && params[:city].nil? && 
       params[:status].nil? && params[:start_date].nil? && params[:end_date].nil? && 
       params[:sort].nil? && params[:page].nil?
      clear_session_filters
    end
    
    @query = params[:query]
    @region_filter = params[:region]
    @city_filter = params[:city]
    @status_filter = params[:status]
    @start_date_filter = params[:start_date]
    @end_date_filter = params[:end_date]
    @sort_filter = params[:sort] || 'newest' # Por defecto: más nuevos
    
    # Guardar los filtros en la sesión para mantenerlos entre actualizaciones
    session[:tournaments_query] = @query
    session[:tournaments_region] = @region_filter
    session[:tournaments_city] = @city_filter
    session[:tournaments_status] = @status_filter
    session[:tournaments_start_date] = @start_date_filter
    session[:tournaments_end_date] = @end_date_filter
    session[:tournaments_sort] = @sort_filter
    
    @tournaments = apply_filters(Tournament.all)
    @tournaments = apply_sorting(@tournaments)
    set_filter_options

    # Aplicar paginación con Kaminari - 100 torneos por página
    @tournaments = @tournaments.page(params[:page]).per(100)

    respond_to do |format|
      format.html do
        if params[:partial] == 'true'
          render partial: 'tournaments_list', locals: { tournaments: @tournaments }
        else
          render :index
        end
      end
      format.turbo_stream
    end
  end
  
  def sync
    begin
      service = SyncSmashData.new
      # Usar el nuevo método que prioriza eventos faltantes antes que seeds
      service.sync_tournaments
      
      respond_to do |format|
        format.html { redirect_to tournaments_path, notice: "Torneos sincronizados exitosamente. Se priorizaron eventos faltantes antes que seeds." }
        format.turbo_stream { 
          flash.now[:notice] = "Torneos sincronizados exitosamente. Se priorizaron eventos faltantes antes que seeds."
          load_tournaments_with_session_filters
          render turbo_stream: [
            turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list", 
              locals: { tournaments: @tournaments }),
            turbo_stream.replace("flash", 
              partial: "shared/flash")
          ]
        }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar: #{e.message}"
          load_tournaments_with_session_filters
          render turbo_stream: [
            turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments }),
            turbo_stream.replace("flash", 
              partial: "shared/flash")
          ]
        }
      end
    end
  end
  
  def sync_new_tournaments
    begin
      service = SyncSmashData.new
      # Usar el nuevo método optimizado que busca solo torneos posteriores al último registrado
      nuevos_torneos = service.sync_tournaments_and_events_atomic
      
      respond_to do |format|
        if nuevos_torneos > 0
          format.html { redirect_to tournaments_path, notice: "✅ Sincronización completada: #{nuevos_torneos} nuevos torneos agregados (solo torneos que no existían en la base de datos)." }
          format.turbo_stream { 
            flash.now[:notice] = "✅ Sincronización: #{nuevos_torneos} nuevos torneos agregados (solo torneos posteriores al último registrado que no existían en BD)."
            load_tournaments_with_session_filters
            render turbo_stream: [
              turbo_stream.replace("tournaments_results", 
                partial: "tournaments/tournaments_list",
                locals: { tournaments: @tournaments }),
              turbo_stream.replace("flash", 
                partial: "shared/flash")
            ]
          }
        else
          format.html { redirect_to tournaments_path, notice: "✨ Base de datos actualizada: no se encontraron torneos nuevos posteriores al último registrado." }
          format.turbo_stream { 
            flash.now[:notice] = "✨ Base de datos actualizada: no se encontraron torneos nuevos para sincronizar."
            load_tournaments_with_session_filters
            render turbo_stream: [
              turbo_stream.replace("tournaments_results", 
                partial: "tournaments/tournaments_list",
                locals: { tournaments: @tournaments }),
              turbo_stream.replace("flash", 
                partial: "shared/flash")
            ]
          }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "❌ Error en sincronización: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "❌ Error en sincronización de nuevos torneos: #{e.message}"
          load_tournaments_with_session_filters
          render turbo_stream: [
            turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments }),
            turbo_stream.replace("flash", 
              partial: "shared/flash")
          ]
        }
      end
    end
  end
  
  def sync_events
    @tournament = Tournament.find(params[:id])
    
    begin
      # Sincronizar eventos para este torneo específico usando el nuevo método
      service = SyncSmashData.new
      nuevos_eventos = service.sync_events_for_single_tournament(@tournament)
      
      respond_to do |format|
        if nuevos_eventos > 0
          format.html { redirect_to tournaments_path, notice: "Se han sincronizado #{nuevos_eventos} eventos para el torneo #{@tournament.name}." }
          format.turbo_stream { 
            flash.now[:notice] = "Se han sincronizado #{nuevos_eventos} eventos para el torneo #{@tournament.name}."
            load_tournaments_with_session_filters
            render turbo_stream: [
              turbo_stream.replace("tournaments_results", 
                partial: "tournaments/tournaments_list",
                locals: { tournaments: @tournaments }),
              turbo_stream.replace("flash", 
                partial: "shared/flash")
            ]
          }
        else
          format.html { redirect_to tournaments_path, notice: "No se encontraron nuevos eventos para el torneo #{@tournament.name}." }
          format.turbo_stream { 
            flash.now[:notice] = "No se encontraron nuevos eventos para el torneo #{@tournament.name}."
            load_tournaments_with_session_filters
            render turbo_stream: [
              turbo_stream.replace("tournaments_results", 
                partial: "tournaments/tournaments_list",
                locals: { tournaments: @tournaments }),
              turbo_stream.replace("flash", 
                partial: "shared/flash")
            ]
          }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar eventos: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar eventos: #{e.message}"
          load_tournaments_with_session_filters
          render turbo_stream: [
            turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments }),
            turbo_stream.replace("flash", 
              partial: "shared/flash")
          ]
        }
      end
    end
  end

  private

  def clear_session_filters
    session[:tournaments_query] = nil
    session[:tournaments_region] = nil
    session[:tournaments_city] = nil
    session[:tournaments_status] = nil
    session[:tournaments_start_date] = nil
    session[:tournaments_end_date] = nil
    session[:tournaments_sort] = nil
  end

  def apply_filters(tournaments_scope)
    # Filtrar por nombre si se proporciona un término de búsqueda
    if @query.present?
      tournaments_scope = tournaments_scope.where("LOWER(tournaments.name) LIKE LOWER(?)", "%#{@query}%")
    end

    # Filtrar por región
    if @region_filter.present? && @region_filter != ''
      tournaments_scope = tournaments_scope.by_region(@region_filter)
    end

    # Filtrar por ciudad
    if @city_filter.present? && @city_filter != ''
      tournaments_scope = tournaments_scope.by_city(@city_filter)
    end

    # Filtrar por estado (pasados/futuros)
    if @status_filter.present? && @status_filter != ''
      case @status_filter
      when 'upcoming'
        tournaments_scope = tournaments_scope.where('start_at > ?', Time.current)
      when 'past'
        tournaments_scope = tournaments_scope.where('start_at <= ?', Time.current)
      end
    end

    # Filtrar por rango de fechas
    if @start_date_filter.present?
      begin
        start_date = Date.parse(@start_date_filter)
        tournaments_scope = tournaments_scope.where('start_at >= ?', start_date.beginning_of_day)
      rescue Date::Error
        # Ignorar fecha inválida
      end
    end

    if @end_date_filter.present?
      begin
        end_date = Date.parse(@end_date_filter)
        tournaments_scope = tournaments_scope.where('start_at <= ?', end_date.end_of_day)
      rescue Date::Error
        # Ignorar fecha inválida
      end
    end

    # Precargar asociaciones y conteos para evitar N+1 queries en la vista
    tournaments_scope
      .includes(events: [:event_seeds]) # Para acceder a los objetos event y event_seed si es necesario
      .left_joins(events: :event_seeds) # Para permitir conteos agregados
      .select('tournaments.*, COUNT(DISTINCT events.id) AS events_count_data, COUNT(DISTINCT event_seeds.id) AS total_event_seeds_count_data')
      .group('tournaments.id')
  end

  def apply_sorting(tournaments_scope)
    case @sort_filter
    when 'oldest'
      tournaments_scope.order(start_at: :asc)
    when 'newest'
      tournaments_scope.order(start_at: :desc)
    when 'most_attendees'
      tournaments_scope.order(Arel.sql('COALESCE(attendees_count, 0) DESC, start_at DESC'))
    when 'least_attendees'
      tournaments_scope.order(Arel.sql('COALESCE(attendees_count, 0) ASC, start_at DESC'))
    when 'alphabetical_az'
      tournaments_scope.order(Arel.sql('LOWER(tournaments.name) ASC'))
    when 'alphabetical_za'
      tournaments_scope.order(Arel.sql('LOWER(tournaments.name) DESC'))
    else
      tournaments_scope.order(start_at: :desc) # Por defecto: más nuevos
    end
  end

  def set_filter_options
    # Obtener listas para los filtros (siempre desde todos los torneos, no filtrados)
    all_tournaments = Tournament.all
    regions_from_db = all_tournaments.where.not(region: [nil, '']).distinct.pluck(:region).compact
    @available_cities = all_tournaments.where.not(city: [nil, '']).distinct.pluck(:city).compact.sort

    # Ordenar regiones según orden geográfico de norte a sur
    region_order = [
      'Arica y Parinacota',
      'Tarapacá',
      'Antofagasta',
      'Atacama',
      'Coquimbo',
      'Valparaíso',
      'Metropolitana de Santiago',
      'O\'Higgins',
      'Libertador Gral. Bernardo O\'Higgins', # Variante del nombre de O'Higgins
      'Maule',
      'Ñuble',
      'Biobío',
      'Araucanía',
      'Los Ríos',
      'Los Lagos',
      'Aysén',
      'Magallanes y Antártica Chilena',
      'Magallanes y de la Antártica Chilena' # Variante del nombre de Magallanes
    ]
    
    # Ordenar las regiones disponibles según el orden geográfico
    @available_regions = region_order.select { |region| regions_from_db.include?(region) }
    
    # Agregar cualquier región que no esté en el orden predefinido al final (como "Online")
    remaining_regions = regions_from_db - @available_regions
    @available_regions += remaining_regions.sort

    # Si no hay regiones/ciudades disponibles, intentar parsear algunas para mostrar opciones
    if @available_regions.empty? && @available_cities.empty?
      Rails.logger.info "No hay regiones/ciudades parseadas, ejecutando parseo parcial..."
      begin
        service = LocationParserService.new
        # Parsear solo los primeros 10 torneos para prueba
        Tournament.where.not(venue_address: [nil, '']).limit(10).each do |tournament|
          service.parse_and_update_tournament(tournament)
        end
        # Recargar las listas con el nuevo ordenamiento
        regions_from_db = Tournament.where.not(region: [nil, '']).distinct.pluck(:region).compact
        @available_regions = region_order.select { |region| regions_from_db.include?(region) }
        remaining_regions = regions_from_db - @available_regions
        @available_regions += remaining_regions.sort
        @available_cities = Tournament.where.not(city: [nil, '']).distinct.pluck(:city).compact.sort
      rescue => e
        Rails.logger.error "Error parseando ubicaciones: #{e.message}"
      end
    end
  end

  def load_tournaments_with_session_filters
    # Usar los filtros guardados en la sesión
    @query = session[:tournaments_query]
    @region_filter = session[:tournaments_region]
    @city_filter = session[:tournaments_city]
    @status_filter = session[:tournaments_status]
    @start_date_filter = session[:tournaments_start_date]
    @end_date_filter = session[:tournaments_end_date]
    @sort_filter = session[:tournaments_sort] || 'newest'
    
    @tournaments = apply_filters(Tournament.all)
    @tournaments = apply_sorting(@tournaments)
    set_filter_options
    
    # Aplicar paginación
    @tournaments = @tournaments.page(params[:page]).per(100)
  end
end
