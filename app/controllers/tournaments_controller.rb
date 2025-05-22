class TournamentsController < ApplicationController
  def index
    @query = params[:query]
    
    # Guardar el término de búsqueda en la sesión para mantenerlo entre actualizaciones
    session[:tournaments_query] = @query
    
    @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds)
    
    # Filtrar por nombre si se proporciona un término de búsqueda
    if @query.present?
      @tournaments = @tournaments.where("LOWER(name) LIKE LOWER(?)", "%#{@query}%")
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def sync
    begin
      service = SyncSmashData.new
      # Modificar call para que sincronice torneos explícitamente
      service.sync_tournaments
      service.sync_events
      
      respond_to do |format|
        format.html { redirect_to tournaments_path, notice: "Torneos y eventos sincronizados exitosamente." }
        format.turbo_stream { 
          flash.now[:notice] = "Torneos y eventos sincronizados exitosamente."
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list", 
            locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
        }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar: #{e.message}"
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list",
            locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
        }
      end
    end
  end
  
  def sync_new_tournaments
    begin
      service = SyncSmashData.new
      # Sincronizar torneos y sus eventos de forma atómica
      nuevos_torneos = service.sync_tournaments_and_events_atomic
      
      respond_to do |format|
        if nuevos_torneos > 0
          format.html { redirect_to tournaments_path, notice: "Se han sincronizado #{nuevos_torneos} nuevos torneos y sus eventos exitosamente." }
          format.turbo_stream { 
            flash.now[:notice] = "Se han sincronizado #{nuevos_torneos} nuevos torneos y sus eventos exitosamente."
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
          }
        else
          format.html { redirect_to tournaments_path, notice: "No se encontraron nuevos torneos para sincronizar." }
          format.turbo_stream { 
            flash.now[:notice] = "No se encontraron nuevos torneos para sincronizar."
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
          }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar nuevos torneos: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar nuevos torneos: #{e.message}"
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list",
            locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
        }
      end
    end
  end
  
  def sync_events
    @tournament = Tournament.find(params[:id])
    
    begin
      # Sincronizar eventos para este torneo específico
      service = SyncSmashData.new
      nuevos_eventos = service.sync_events_for_tournament(@tournament)
      
      respond_to do |format|
        if nuevos_eventos > 0
          format.html { redirect_to tournaments_path, notice: "Se han sincronizado #{nuevos_eventos} eventos para el torneo #{@tournament.name}." }
          format.turbo_stream { 
            flash.now[:notice] = "Se han sincronizado #{nuevos_eventos} eventos para el torneo #{@tournament.name}."
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
          }
        else
          format.html { redirect_to tournaments_path, notice: "No se encontraron nuevos eventos para el torneo #{@tournament.name}." }
          format.turbo_stream { 
            flash.now[:notice] = "No se encontraron nuevos eventos para el torneo #{@tournament.name}."
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
          }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to tournaments_path, alert: "Error al sincronizar eventos: #{e.message}" }
        format.turbo_stream {
          flash.now[:alert] = "Error al sincronizar eventos: #{e.message}"
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list",
            locals: { tournaments: Tournament.order(start_at: :desc).includes(events: :event_seeds) })
        }
      end
    end
  end
end
