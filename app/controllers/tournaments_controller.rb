class TournamentsController < ApplicationController
  def index
    @query = params[:query]
    @region_filter = params[:region]
    @city_filter = params[:city]
    
    # Guardar los filtros en la sesión para mantenerlos entre actualizaciones
    session[:tournaments_query] = @query
    session[:tournaments_region] = @region_filter
    session[:tournaments_city] = @city_filter
    
    @tournaments = apply_filters(Tournament.order(start_at: :desc).includes(events: :event_seeds))
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
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list", 
            locals: { tournaments: @tournaments })
        }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar: #{e.message}"
          load_tournaments_with_session_filters
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list",
            locals: { tournaments: @tournaments })
        }
      end
    end
  end
  
  def sync_new_tournaments
    begin
      service = SyncSmashData.new
      # Usar el nuevo método que busca solo torneos posteriores a la fecha del último torneo
      nuevos_torneos = service.sync_tournaments_and_events_atomic
      
      respond_to do |format|
        if nuevos_torneos > 0
          format.html { redirect_to tournaments_path, notice: "Se han sincronizado #{nuevos_torneos} nuevos torneos (posteriores al último registrado) con sus eventos exitosamente." }
          format.turbo_stream { 
            flash.now[:notice] = "Se han sincronizado #{nuevos_torneos} nuevos torneos (posteriores al último registrado) con sus eventos exitosamente."
            load_tournaments_with_session_filters
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments })
          }
        else
          format.html { redirect_to tournaments_path, notice: "No se encontraron torneos nuevos posteriores al último registrado para sincronizar." }
          format.turbo_stream { 
            flash.now[:notice] = "No se encontraron torneos nuevos posteriores al último registrado para sincronizar."
            load_tournaments_with_session_filters
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments })
          }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar nuevos torneos: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar nuevos torneos: #{e.message}"
          load_tournaments_with_session_filters
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list",
            locals: { tournaments: @tournaments })
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
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments })
          }
        else
          format.html { redirect_to tournaments_path, notice: "No se encontraron nuevos eventos para el torneo #{@tournament.name}." }
          format.turbo_stream { 
            flash.now[:notice] = "No se encontraron nuevos eventos para el torneo #{@tournament.name}."
            load_tournaments_with_session_filters
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments })
          }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar eventos: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar eventos: #{e.message}"
          load_tournaments_with_session_filters
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list",
            locals: { tournaments: @tournaments })
        }
      end
    end
  end

  private

  def apply_filters(tournaments_scope)
    # Filtrar por nombre si se proporciona un término de búsqueda
    if @query.present?
      tournaments_scope = tournaments_scope.where("LOWER(name) LIKE LOWER(?)", "%#{@query}%")
    end

    # Filtrar por región
    if @region_filter.present? && @region_filter != ''
      tournaments_scope = tournaments_scope.by_region(@region_filter)
    end

    # Filtrar por ciudad
    if @city_filter.present? && @city_filter != ''
      tournaments_scope = tournaments_scope.by_city(@city_filter)
    end

    tournaments_scope
  end

  def set_filter_options
    # Obtener listas para los filtros (siempre desde todos los torneos, no filtrados)
    all_tournaments = Tournament.all
    @available_regions = all_tournaments.where.not(region: [nil, '']).distinct.pluck(:region).compact.sort
    @available_cities = all_tournaments.where.not(city: [nil, '']).distinct.pluck(:city).compact.sort

    # Si no hay regiones/ciudades disponibles, intentar parsear algunas para mostrar opciones
    if @available_regions.empty? && @available_cities.empty?
      Rails.logger.info "No hay regiones/ciudades parseadas, ejecutando parseo parcial..."
      begin
        service = LocationParserService.new
        # Parsear solo los primeros 10 torneos para prueba
        Tournament.where.not(venue_address: [nil, '']).limit(10).each do |tournament|
          service.parse_and_update_tournament(tournament)
        end
        # Recargar las listas
        @available_regions = Tournament.where.not(region: [nil, '']).distinct.pluck(:region).compact.sort
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
    
    @tournaments = apply_filters(Tournament.order(start_at: :desc).includes(events: :event_seeds))
    set_filter_options
    
    # Aplicar paginación
    @tournaments = @tournaments.page(params[:page]).per(100)
  end
end
