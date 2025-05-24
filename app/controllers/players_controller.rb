class PlayersController < ApplicationController
  def index
    @query = params[:query]
    
    Rails.logger.info "=== Players#index called with query: '#{@query}', format: #{request.format} ==="
    
    # Guardar el término de búsqueda en la sesión
    session[:players_query] = @query
    
    # Usar el método helper para preparar los datos
    @players = prepare_players_data

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

  def update_smash_characters
    @player = Player.find(params[:id])
    
    # Parámetros permitidos para personajes de Smash
    character_params = params.permit(:character_1, :skin_1, :character_2, :skin_2, :character_3, :skin_3)
    
    # Convertir a hash para poder iterarlo correctamente
    params_hash = character_params.to_h
    
    # Limpiar valores vacíos - convertir strings vacías a nil
    params_hash.each do |key, value|
      if key.to_s.starts_with?('character_') && value.blank?
        params_hash[key] = nil
      elsif key.to_s.starts_with?('skin_') && value.blank?
        params_hash[key] = 1  # Skin por defecto
      end
    end
    
    # Actualizar solo los campos de personajes sin ejecutar validaciones completas
    success = @player.update_columns(params_hash)
    
    if success
      respond_to do |format|
        format.json { render json: { success: true, message: 'Personajes actualizados correctamente' } }
        format.turbo_stream { 
          # Preparar datos para la recarga
          @query = session[:players_query]
          @players = prepare_players_data
          
          render turbo_stream: turbo_stream.replace("players_results", 
            partial: "players_list", 
            locals: { players: @players }
          )
        }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, error: 'Error al actualizar personajes' } }
        format.turbo_stream { render json: { success: false, error: 'Error al actualizar personajes' } }
      end
    end
  end

  def current_characters
    @player = Player.find(params[:id])
    
    render json: {
      success: true,
      character_1: @player.character_1,
      skin_1: @player.skin_1,
      character_2: @player.character_2,
      skin_2: @player.skin_2,
      character_3: @player.character_3,
      skin_3: @player.skin_3
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Jugador no encontrado' }
  end

  private

  def player_params
    params.require(:player).permit(:character_1, :skin_1, :character_2, :skin_2, :character_3, :skin_3)
  end

  def prepare_players_data
    # Reutilizar la misma lógica del método index
    players = Player.includes(event_seeds: { event: :tournament })
    
    # Filtrar por nombre si se proporciona un término de búsqueda
    if @query.present?
      players = players.where(
        "LOWER(players.name) LIKE LOWER(?) OR LOWER(players.entrant_name) LIKE LOWER(?) OR LOWER(players.twitter_handle) LIKE LOWER(?)", 
        "%#{@query}%", "%#{@query}%", "%#{@query}%"
      )
    end

    # Obtener solo jugadores que tienen al menos un event_seed
    players = players.joins(:event_seeds).distinct
    
    # Convertir a array para hacer el ordenamiento en memoria y preservar los includes
    players_array = players.to_a
    
    # Ordenamiento personalizado en memoria
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
    
    # Simular la funcionalidad de Kaminari
    Kaminari.paginate_array(players_array, total_count: total_count)
            .page(page).per(per_page)
  end
end 