class PlayersController < ApplicationController
  def index
    @query = params[:query]
    
    Rails.logger.info "=== Players#index called with query: '#{@query}', format: #{request.format} ==="
    
    # Guardar el término de búsqueda en la sesión
    session[:players_query] = @query
    
    # Estrategia de ordenamiento sin group que interfiera con includes
    @players = Player.includes(event_seeds: { event: :tournament })
    
    # Filtrar por nombre si se proporciona un término de búsqueda
    if @query.present?
      @players = @players.where(
        "LOWER(players.name) LIKE LOWER(?) OR LOWER(players.entrant_name) LIKE LOWER(?) OR LOWER(players.twitter_handle) LIKE LOWER(?)", 
        "%#{@query}%", "%#{@query}%", "%#{@query}%"
      )
    end

    # Obtener solo jugadores que tienen al menos un event_seed
    @players = @players.joins(:event_seeds).distinct
    
    # Convertir a array para hacer el ordenamiento en memoria y preservar los includes
    players_array = @players.to_a
    
    # Ordenamiento personalizado en memoria:
    # 1) Por inscripción más reciente a un evento (última participación)
    # 2) Por mayor cantidad de eventos (de más a menos)
    players_array.sort! do |a, b|
      # Obtener fechas de eventos más recientes
      latest_a = a.event_seeds.map { |es| es.event.tournament.start_at }.max
      latest_b = b.event_seeds.map { |es| es.event.tournament.start_at }.max
      
      # Primero ordenar por fecha más reciente (DESC)
      date_comparison = (latest_b || Time.at(0)) <=> (latest_a || Time.at(0))
      
      if date_comparison != 0
        date_comparison
      else
        # Si las fechas son iguales, ordenar por cantidad de eventos (DESC)
        b.event_seeds.size <=> a.event_seeds.size
      end
    end
    
    # Aplicar paginación manualmente sobre el array ordenado
    page = (params[:page] || 1).to_i
    per_page = 100
    total_count = players_array.size
    offset = (page - 1) * per_page
    
    # Simular la funcionalidad de Kaminari
    @players = Kaminari.paginate_array(players_array, total_count: total_count)
                      .page(page).per(per_page)

    Rails.logger.info "=== Found #{@players.size} players, responding with format: #{request.format} ==="

    respond_to do |format|
      format.html do 
        Rails.logger.info "=== Responding with HTML ==="
        if params[:partial] == 'true'
          render partial: 'players_list', locals: { players: @players }
        else
          render :index
        end
      end
      format.turbo_stream { Rails.logger.info "=== Responding with TURBO_STREAM ===" }
    end
  end

  def search
    redirect_to players_path(query: params[:query])
  end
end 