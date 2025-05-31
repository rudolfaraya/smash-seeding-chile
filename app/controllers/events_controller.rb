class EventsController < ApplicationController
  # Requerir autenticación para sync_seeds
  before_action :authenticate_user!, only: [ :sync_seeds ]

  before_action :set_tournament, only: [ :index, :show, :seeds, :sync_seeds, :export_seeds, :export_seeds_html ]
  before_action :set_event, only: [ :show, :seeds, :sync_seeds, :export_seeds, :export_seeds_html ]

  def index
    @events = policy_scope(@tournament.events)
  end

  def show
  end

  def seeds
    @seeds = @event.event_seeds.includes(:player).order(seed_num: :asc)

    respond_to do |format|
      format.html {
        # Si es una petición AJAX (desde nuestro controlador Stimulus)
        if request.xhr?
          render partial: "events/seeds_list",
                locals: { seeds: @seeds, event: @event, tournament: @tournament },
                layout: false
        else
          # Renderizar la vista completa normalmente
          render :seeds
        end
      }
      format.turbo_stream { render :seeds }
    end
  end

  def sync_seeds
    authorize @event

    Rails.logger.info "=== Sincronización de seeds del evento #{@event.id} iniciada ==="
    Rails.logger.info "Event: #{@event.name} (#{@event.tournament.name})"

    begin
      force = params[:force].present?
      update_players = params[:update_players].present?
      immediate = params[:immediate].present? # Nueva opción para debugging

      Rails.logger.info "Parámetros recibidos:"
      Rails.logger.info "  Force: #{force}"
      Rails.logger.info "  Update Players: #{update_players}"
      Rails.logger.info "  Immediate: #{immediate}"

      if immediate
        # Ejecutar inmediatamente para debugging
        Rails.logger.info "🔥 EJECUCIÓN INMEDIATA (DEBUGGING)"
        result = SyncEventSeedsJob.perform_now(@event.id, { force: force, update_players: update_players })
        Rails.logger.info "Resultado inmediato: #{result}"

        # Recargar datos
        @event.reload

        respond_to do |format|
          format.html {
            redirect_to seeds_tournament_event_path(@tournament, @event),
                       notice: "✅ Sincronización inmediata completada. Seeds: #{@event.event_seeds.count}"
          }
          format.turbo_stream {
            flash.now[:notice] = "✅ Sincronización inmediata de #{@event.name} completada. Seeds capturados: #{@event.event_seeds.count}"
            load_tournaments_with_filters

            render turbo_stream: [
              turbo_stream.replace("tournaments_results",
                partial: "tournaments/tournaments_list",
                locals: { tournaments: @tournaments }),
              turbo_stream.replace("flash",
                partial: "shared/flash")
            ]
          }
        end
      else
        # Ejecutar en background (comportamiento original)
        job = SyncEventSeedsJob.perform_later(@event.id, { force: force, update_players: update_players })
        Rails.logger.info "Job encolado con ID: #{job.job_id}"

        respond_to do |format|
          format.html {
            if force
              redirect_to seeds_tournament_event_path(@tournament, @event), notice: "Sincronización forzada de seeds iniciada en segundo plano. Job ID: #{job.job_id}"
            else
              redirect_to seeds_tournament_event_path(@tournament, @event), notice: "Sincronización de seeds iniciada en segundo plano. Job ID: #{job.job_id}"
            end
          }
          format.turbo_stream {
            if force
              flash.now[:notice] = "Sincronización forzada de seeds de #{@event.name} iniciada en segundo plano. Puedes monitorear el progreso en Mission Control."
            else
              flash.now[:notice] = "Sincronización de seeds de #{@event.name} iniciada en segundo plano. Puedes monitorear el progreso en Mission Control."
            end

            load_tournaments_with_filters

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
      Rails.logger.error "❌ ERROR al iniciar sincronización de seeds del evento #{@event.id}"
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(10).join('\n')}"

      error_message = if immediate
                       "❌ Error en sincronización inmediata: #{e.message}"
      else
                       "❌ Error al iniciar sincronización: #{e.message}"
      end

      respond_to do |format|
        format.html { redirect_to seeds_tournament_event_path(@tournament, @event), alert: error_message }
        format.turbo_stream {
          flash.now[:alert] = error_message
          load_tournaments_with_filters
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

  def export_seeds
    @seeds = @event.event_seeds.includes(player: [ :teams ]).order(seed_num: :asc)

    # Verificar que hay seeds para exportar
    if @seeds.empty?
      redirect_to seeds_tournament_event_path(@tournament, @event),
                  alert: "No hay seeds disponibles para exportar. Sincroniza primero el evento."
      return
    end

    # Renderizar la vista de exportación
    render :export_seeds, layout: false
  end

  def export_seeds_html
    @seeds = @event.event_seeds.includes(player: [ :teams ]).order(seed_num: :asc)

    # Verificar que hay seeds para exportar
    if @seeds.empty?
      redirect_to seeds_tournament_event_path(@tournament, @event),
                  alert: "No hay seeds disponibles para exportar. Sincroniza primero el evento."
      return
    end

    # Generar el HTML standalone
    html_content = render_to_string("events/export_seeds_standalone", layout: false)

    # Configurar headers para descarga
    filename = "#{@tournament.name.parameterize}-#{@event.name.parameterize}-seeds.html"

    send_data html_content,
              type: "text/html",
              disposition: "attachment",
              filename: filename
  end

  private

  def set_tournament
    @tournament = Tournament.find(params[:tournament_id])
  end

  def set_event
    @event = @tournament.events.find(params[:id])
  end

  def load_tournaments_with_filters
    # Obtener filtros de la sesión (igual que en tournaments_controller)
    @query = session[:tournaments_query]
    @region_filter = session[:tournaments_region]
    @city_filter = session[:tournaments_city]

    # Obtener torneos con includes optimizados
    @tournaments = Tournament.includes(events: { event_seeds: :player }).order(start_at: :desc)

    # Aplicar filtros
    if @query.present?
      @tournaments = @tournaments.where("LOWER(name) LIKE LOWER(?)", "%#{@query}%")
    end

    if @region_filter.present? && @region_filter != ""
      @tournaments = @tournaments.by_region(@region_filter)
    end

    if @city_filter.present? && @city_filter != ""
      @tournaments = @tournaments.by_city(@city_filter)
    end

    # Aplicar paginación
    @tournaments = @tournaments.page(params[:page]).per(100)
  end
end
