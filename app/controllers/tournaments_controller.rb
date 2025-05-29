class TournamentsController < ApplicationController
  # Requerir autenticación para acciones de sincronización
  before_action :authenticate_user!, only: [:sync, :sync_new_tournaments, :sync_events, :sync_latest_tournaments]

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def index
    Rails.logger.info "=== Tournaments#index called with query: '#{params[:query]}', region: '#{params[:region]}', city: '#{params[:city]}', status: '#{params[:status]}', sort: '#{params[:sort]}', page: '#{params[:page]}', format: #{request.format} ==="

    # Si no hay parámetros de filtros, limpiar la sesión (clear all)
    if params[:query].nil? && params[:region].nil? && params[:city].nil? &&
       params[:status].nil? && params[:start_date].nil? && params[:end_date].nil? &&
       params[:sort].nil? && params[:page].nil?
      clear_session_filters
    end

    # Extraer parámetros para variables de instancia (para las vistas)
    @query = params[:query] || session[:tournaments_query]
    @region_filter = params[:region] || session[:tournaments_region]
    @city_filter = params[:city] || session[:tournaments_city]
    @status_filter = params[:status] || session[:tournaments_status]
    @start_date_filter = params[:start_date] || session[:tournaments_start_date]
    @end_date_filter = params[:end_date] || session[:tournaments_end_date]
    @sort_filter = params[:sort] || session[:tournaments_sort] || "newest"

    # Guardar los filtros en la sesión para mantenerlos entre actualizaciones
    save_filter_params_to_session

    # Configurar opciones de filtros primero
    set_filter_options
    
    # Usar el servicio para obtener los torneos filtrados
    @tournaments = TournamentsFilterService.new(params, session).call

    Rails.logger.info "=== Found #{@tournaments.respond_to?(:total_count) ? @tournaments.total_count : @tournaments.size} tournaments with current filters ==="

    respond_to do |format|
      format.html do
        if params[:partial] == "true"
          render partial: "tournaments_list", locals: { tournaments: @tournaments }
        else
          render :index
        end
      end
      format.turbo_stream
    end
  end

  def show
    @tournament = Tournament.find(params[:id])
    @events = @tournament.events.includes(:event_seeds)
  end

  def sync
    begin
      # Encolar job de sincronización general de torneos
      job = SyncTournamentsJob.perform_later

      respond_to do |format|
        format.html { redirect_to tournaments_path, notice: "Sincronización de torneos iniciada en segundo plano. Job ID: #{job.job_id}" }
        format.turbo_stream {
          flash.now[:notice] = "Sincronización de torneos iniciada en segundo plano. Puedes monitorear el progreso en Mission Control."
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
        format.html { redirect_to tournaments_path, alert: "Error al iniciar sincronización: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al iniciar sincronización: #{e.message}"
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
      # Encolar job de sincronización de nuevos torneos
      job = SyncNewTournamentsJob.perform_later

      respond_to do |format|
        format.html { redirect_to tournaments_path, notice: "Sincronización de nuevos torneos iniciada en segundo plano. Job ID: #{job.job_id}" }
        format.turbo_stream {
          flash.now[:notice] = "Sincronización de nuevos torneos iniciada en segundo plano. Puedes monitorear el progreso en Mission Control."
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
        format.html { redirect_to tournaments_path, alert: "❌ Error al iniciar sincronización: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "❌ Error al iniciar sincronización de nuevos torneos: #{e.message}"
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
      # Encolar job de sincronización de eventos para este torneo específico
      job = SyncTournamentEventsJob.perform_later(@tournament.id)

      respond_to do |format|
        format.html { redirect_to tournaments_path, notice: "Sincronización de eventos iniciada para el torneo #{@tournament.name}. Job ID: #{job.job_id}" }
        format.turbo_stream {
          flash.now[:notice] = "Sincronización de eventos iniciada para el torneo #{@tournament.name}. Puedes monitorear el progreso en Mission Control."
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
        format.html { redirect_to tournaments_path, alert: "Error al iniciar sincronización de eventos: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al iniciar sincronización de eventos: #{e.message}"
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

  def sync_latest_tournaments
    begin
      # Encolar job de actualización de los últimos 20 torneos
      job = SyncLatestTournamentsJob.perform_later({ limit: 20, force: true })

      respond_to do |format|
        format.html { redirect_to tournaments_path, notice: "Actualización forzada de los últimos 20 torneos iniciada en segundo plano. Job ID: #{job.job_id}" }
        format.turbo_stream {
          flash.now[:notice] = "Actualización forzada de los últimos 20 torneos iniciada en segundo plano. Puedes monitorear el progreso en Mission Control."
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
        format.html { redirect_to tournaments_path, alert: "❌ Error al iniciar actualización de últimos torneos: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "❌ Error al iniciar actualización de últimos torneos: #{e.message}"
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

  def save_filter_params_to_session
    session[:tournaments_query] = @query
    session[:tournaments_region] = @region_filter
    session[:tournaments_city] = @city_filter
    session[:tournaments_status] = @status_filter
    session[:tournaments_start_date] = @start_date_filter
    session[:tournaments_end_date] = @end_date_filter
    session[:tournaments_sort] = @sort_filter
  end

  def set_filter_options
    # Obtener listas para los filtros (siempre desde todos los torneos, no filtrados)
    all_tournaments = Tournament.all
    regions_from_db = all_tournaments.where.not(region: [ nil, "" ]).distinct.pluck(:region).compact
    @available_cities = all_tournaments.where.not(city: [ nil, "" ]).distinct.pluck(:city).compact.sort

    # Ordenar regiones según orden geográfico de norte a sur
    region_order = [
      "Arica y Parinacota",
      "Tarapacá",
      "Antofagasta",
      "Atacama",
      "Coquimbo",
      "Valparaíso",
      "Metropolitana de Santiago",
      "O'Higgins",
      "Libertador Gral. Bernardo O'Higgins", # Variante del nombre de O'Higgins
      "Maule",
      "Ñuble",
      "Biobío",
      "Araucanía",
      "Los Ríos",
      "Los Lagos",
      "Aysén",
      "Magallanes y Antártica Chilena",
      "Magallanes y de la Antártica Chilena" # Variante del nombre de Magallanes
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
        Tournament.where.not(venue_address: [ nil, "" ]).limit(10).each do |tournament|
          service.parse_and_update_tournament(tournament)
        end
        # Recargar las listas con el nuevo ordenamiento
        regions_from_db = Tournament.where.not(region: [ nil, "" ]).distinct.pluck(:region).compact
        @available_regions = region_order.select { |region| regions_from_db.include?(region) }
        remaining_regions = regions_from_db - @available_regions
        @available_regions += remaining_regions.sort
        @available_cities = Tournament.where.not(city: [ nil, "" ]).distinct.pluck(:city).compact.sort
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
    @sort_filter = session[:tournaments_sort] || "newest"

    @tournaments = apply_filters(Tournament.all)
    @tournaments = apply_sorting(@tournaments)
    set_filter_options

    # Aplicar paginación
    @tournaments = @tournaments.page(params[:page]).per(100)
  end

  def record_not_found
    respond_to do |format|
      format.html { render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false }
      format.json { render json: { error: "Not found" }, status: :not_found }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: "Recurso no encontrado" } }) }
    end
  end
end
