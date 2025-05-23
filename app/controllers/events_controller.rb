class EventsController < ApplicationController
  before_action :set_tournament, only: [ :index, :show, :seeds, :sync_seeds ]
  before_action :set_event, only: [ :show, :seeds, :sync_seeds ]

  def index
    @events = @tournament.events
  end

  def show
  end

  def seeds
    @seeds = @event.event_seeds.order(seed_num: :asc)
    
    # Verificar explícitamente que estamos mostrando los seeds del evento correcto
    event_id = params[:event_id] || request.headers['Event-Id']
    if event_id.present? && event_id.to_i != @event.id
      # Si el evento solicitado no coincide con el de la URL, redirigir o enviar error
      respond_to do |format|
        format.html { 
          flash[:alert] = "Error de sincronización de eventos. Por favor inténtalo de nuevo."
          redirect_to tournaments_path
        }
        format.json { render json: { error: "ID de evento no coincide" }, status: :bad_request }
        format.text { render plain: "Error: ID de evento no coincide", status: :bad_request }
      end
      return
    end
    
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
                      notice: "Seeds ya sincronizados (última sincronización: #{@event.seeds_last_synced_at.strftime('%d/%m/%Y %H:%M')}). Utiliza el parámetro force=true para forzar la sincronización."
        }
        format.turbo_stream {
          flash.now[:notice] = "Seeds ya sincronizados (última sincronización: #{@event.seeds_last_synced_at.strftime('%d/%m/%Y %H:%M')}). Utiliza el parámetro force=true para forzar la sincronización."
          
          # Obtener todos los torneos con datos actualizados para la vista
          # Mantener el orden original por fecha de inicio
          @tournaments = Tournament.includes(events: {event_seeds: :player})
                        .order(start_at: :desc)
          
          # Aplicar el filtro de búsqueda si existe
          @query = session[:tournaments_query]
          if @query.present?
            @tournaments = @tournaments.where("LOWER(name) LIKE LOWER(?)", "%#{@query}%")
          end
          
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
      SyncEventSeeds.new(@event).call
      
      # Actualizar el timestamp de sincronización si el modelo soporta este campo
      if @event.respond_to?(:seeds_last_synced_at)
        @event.update(seeds_last_synced_at: Time.current)
      end
      
      respond_to do |format|
        format.html { redirect_to seeds_tournament_event_path(@tournament, @event), notice: "Seeds y jugadores sincronizados exitosamente." }
        format.turbo_stream {
          flash.now[:notice] = "Seeds y jugadores de #{@event.name} sincronizados exitosamente"
          
          # Obtener todos los torneos con datos actualizados para la vista
          # Mantener el orden original por fecha de inicio
          @tournaments = Tournament.includes(events: {event_seeds: :player})
                        .order(start_at: :desc)
          
          # Aplicar el filtro de búsqueda si existe
          @query = session[:tournaments_query]
          if @query.present?
            @tournaments = @tournaments.where("LOWER(name) LIKE LOWER(?)", "%#{@query}%")
          end
          
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
          
          # Obtener todos los torneos con datos actualizados para la vista
          # Mantener el orden original por fecha de inicio
          @tournaments = Tournament.includes(events: {event_seeds: :player})
                        .order(start_at: :desc)
          
          # Aplicar el filtro de búsqueda si existe
          @query = session[:tournaments_query]
          if @query.present?
            @tournaments = @tournaments.where("LOWER(name) LIKE LOWER(?)", "%#{@query}%")
          end
          
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
end
