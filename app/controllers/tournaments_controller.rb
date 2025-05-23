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

    # Aplicar paginación con Kaminari - 100 torneos por página
    @tournaments = @tournaments.page(params[:page]).per(100)

    respond_to do |format|
      format.html
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
          @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
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
          @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
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
            @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments })
          }
        else
          format.html { redirect_to tournaments_path, notice: "No se encontraron torneos nuevos posteriores al último registrado para sincronizar." }
          format.turbo_stream { 
            flash.now[:notice] = "No se encontraron torneos nuevos posteriores al último registrado para sincronizar."
            @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
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
          @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
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
            @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
            render turbo_stream: turbo_stream.replace("tournaments_results", 
              partial: "tournaments/tournaments_list",
              locals: { tournaments: @tournaments })
          }
        else
          format.html { redirect_to tournaments_path, notice: "No se encontraron nuevos eventos para el torneo #{@tournament.name}." }
          format.turbo_stream { 
            flash.now[:notice] = "No se encontraron nuevos eventos para el torneo #{@tournament.name}."
            @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
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
          @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds).page(params[:page]).per(100)
          render turbo_stream: turbo_stream.replace("tournaments_results", 
            partial: "tournaments/tournaments_list",
            locals: { tournaments: @tournaments })
        }
      end
    end
  end
end
