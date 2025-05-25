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
    # Usar una consulta más simple pero eficiente
    players_query = Player.joins(:event_seeds).distinct
    
    # Filtrar por nombre si se proporciona un término de búsqueda
    if @query.present?
      players_query = players_query.where(
        "LOWER(players.name) LIKE LOWER(?) OR LOWER(players.entrant_name) LIKE LOWER(?) OR LOWER(players.twitter_handle) LIKE LOWER(?)", 
        "%#{@query}%", "%#{@query}%", "%#{@query}%"
      )
    end

    # Aplicar paginación primero
    page = (params[:page] || 1).to_i
    per_page = 50
    
    # Obtener los IDs paginados
    paginated_player_ids = players_query.page(page).per(per_page).pluck(:id)
    
    # Cargar los jugadores con sus asociaciones y datos calculados
    players_with_data = Player.includes(event_seeds: { event: :tournament })
                              .where(id: paginated_player_ids)
                              .map do |player|
      # Calcular datos en Ruby para evitar problemas de SQL
      latest_date = player.event_seeds.map { |es| es.event.tournament.start_at }.compact.max
      events_count = player.event_seeds.size
      
      # Agregar atributos virtuales para ordenamiento
      player.define_singleton_method(:latest_tournament_date) { latest_date }
      player.define_singleton_method(:events_count) { events_count }
      player
    end
    
    # Ordenar en Ruby
    players_with_data.sort! do |a, b|
      # Primero por fecha más reciente (DESC)
      date_a = a.latest_tournament_date || Time.at(0)
      date_b = b.latest_tournament_date || Time.at(0)
      date_comparison = date_b <=> date_a
      
      if date_comparison != 0
        date_comparison
      else
        # Luego por cantidad de eventos (DESC)
        events_comparison = b.events_count <=> a.events_count
        if events_comparison != 0
          events_comparison
        else
          # Finalmente por nombre (ASC)
          a.name <=> b.name
        end
      end
    end
    
    # Simular la paginación de Kaminari con los datos ordenados
    total_count = players_query.count
    Kaminari.paginate_array(players_with_data, total_count: total_count)
            .page(page).per(per_page)
  end
end 