class EventsController < ApplicationController
  before_action :set_tournament, only: [ :index, :show, :seeds, :sync_seeds ]
  before_action :set_event, only: [ :show, :seeds, :sync_seeds ]

  def index
    @events = @tournament.events
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
    # Verificar si el evento fue sincronizado recientemente (últimas 24 horas)
    if @event.respond_to?(:seeds_last_synced_at) &&
       @event.seeds_last_synced_at.present? &&
       @event.seeds_last_synced_at > 24.hours.ago &&
       @event.event_seeds.exists? &&
       !params[:force]

      respond_to do |format|
        # Si ya fue sincronizado recientemente y tiene seeds, redirigir sin volver a sincronizar
        format.html {
          redirect_to seeds_tournament_event_path(@tournament, @event),
                      notice: "Seeds ya sincronizados (última sincronización: #{helpers.format_datetime_cl(@event.seeds_last_synced_at)}). Utiliza el parámetro force=true para forzar la sincronización."
        }
        format.turbo_stream {
          flash.now[:notice] = "Seeds ya sincronizados (última sincronización: #{helpers.format_datetime_cl(@event.seeds_last_synced_at)}). Utiliza el parámetro force=true para forzar la sincronización."

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
      return
    end

    begin
      force = params[:force].present?
      SyncEventSeeds.new(@event, force: force).call

      # Actualizar el timestamp de sincronización si el modelo soporta este campo
      if @event.respond_to?(:seeds_last_synced_at)
        @event.update(seeds_last_synced_at: Time.current)
      end

      respond_to do |format|
        format.html {
          if force
            redirect_to seeds_tournament_event_path(@tournament, @event), notice: "Seeds sincronizados forzadamente y actualizados exitosamente."
          else
            redirect_to seeds_tournament_event_path(@tournament, @event), notice: "Seeds y jugadores sincronizados exitosamente."
          end
        }
        format.turbo_stream {
          if force
            flash.now[:notice] = "Seeds de #{@event.name} sincronizados forzadamente y actualizados exitosamente"
          else
            flash.now[:notice] = "Seeds y jugadores de #{@event.name} sincronizados exitosamente"
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
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to seeds_tournament_event_path(@tournament, @event), alert: "Error al sincronizar: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar seeds: #{e.message}"

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
