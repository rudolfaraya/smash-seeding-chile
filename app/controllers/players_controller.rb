class PlayersController < ApplicationController
  # Requerir autenticación para update_smash_characters y update_info
  before_action :authenticate_user!, only: [:update_smash_characters, :update_info]

  def index
    @query = params[:query]
    @character_filter = params[:character_filter]
    @team_filter = params[:team_filter]
    @country_filter = params[:country_filter]
    @sort_by = params[:sort_by]
    @page = params[:page]

    Rails.logger.info "=== Players#index called with query: '#{@query}', character_filter: '#{@character_filter}', team_filter: '#{@team_filter}', country_filter: '#{@country_filter}', sort_by: '#{@sort_by}', page: '#{@page}', format: #{request.format} ==="

    # Guardar todos los parámetros de filtro en la sesión
    session[:players_query] = @query
    session[:players_character_filter] = @character_filter
    session[:players_team_filter] = @team_filter
    session[:players_country_filter] = @country_filter
    session[:players_sort_by] = @sort_by
    session[:players_page] = @page

    # Usar el método helper para preparar los datos
    @players = prepare_players_data

    Rails.logger.info "=== Found #{@players.size} players, responding with format: #{request.format} ==="

    respond_to do |format|
      format.html do
        Rails.logger.info "=== Responding with HTML ==="
        # Detectar si es una solicitud de Turbo Frame o partial
        if params[:partial] == "true" || turbo_frame_request?
          Rails.logger.info "=== Rendering partial for Turbo Frame ==="
          render partial: "players_list", locals: { players: @players }
        else
          Rails.logger.info "=== Rendering full page ==="
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
      if key.to_s.starts_with?("character_") && value.blank?
        params_hash[key] = nil
      elsif key.to_s.starts_with?("skin_") && value.blank?
        params_hash[key] = 1  # Skin por defecto
      end
    end

    # Actualizar solo los campos de personajes sin ejecutar validaciones completas
    success = @player.update_columns(params_hash)

    if success
      respond_to do |format|
        format.json { render json: { success: true, message: "Personajes actualizados correctamente" } }
        format.turbo_stream {
          # Preparar datos para la recarga usando parámetros de la sesión
          @query = session[:players_query]
          @character_filter = session[:players_character_filter]
          @team_filter = session[:players_team_filter]
          @country_filter = session[:players_country_filter]
          @sort_by = session[:players_sort_by]
          @page = session[:players_page]
          @players = prepare_players_data

          # Construir la URL correcta para la redirección
          redirect_params = {
            query: @query,
            character_filter: @character_filter,
            team_filter: @team_filter,
            country_filter: @country_filter,
            sort_by: @sort_by,
            page: @page
          }.compact
          
          redirect_url = players_path(redirect_params)
          
          render turbo_stream: turbo_stream.action(:visit, redirect_url)
        }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, error: "Error al actualizar personajes" } }
        format.turbo_stream { render json: { success: false, error: "Error al actualizar personajes" } }
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
    render json: { success: false, error: "Jugador no encontrado" }
  end

  def edit_info
    @player = Player.find(params[:id])

    respond_to do |format|
      format.html { render partial: "edit_info_modal", locals: { player: @player } }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("edit_info_modal_content",
          partial: "edit_info_modal",
          locals: { player: @player }
        )
      }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to players_path, alert: "Jugador no encontrado" }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("edit_info_modal_content", "")
      }
    end
  end

  def update_info
    @player = Player.find(params[:id])

    if @player.update(player_info_params)
      respond_to do |format|
        format.json { render json: { success: true, message: "Información actualizada correctamente" } }
        format.turbo_stream {
          # Preparar datos para la recarga usando parámetros de la sesión
          @query = session[:players_query]
          @character_filter = session[:players_character_filter]
          @team_filter = session[:players_team_filter]
          @country_filter = session[:players_country_filter]
          @sort_by = session[:players_sort_by]
          @page = session[:players_page]
          @players = prepare_players_data

          # Construir la URL correcta para la redirección
          redirect_params = {
            query: @query,
            character_filter: @character_filter,
            team_filter: @team_filter,
            country_filter: @country_filter,
            sort_by: @sort_by,
            page: @page
          }.compact
          
          redirect_url = players_path(redirect_params)
          
          render turbo_stream: turbo_stream.action(:visit, redirect_url)
        }
        format.html { redirect_to players_path, notice: "Información actualizada correctamente" }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @player.errors.full_messages } }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("edit_info_modal_content",
            partial: "edit_info_modal",
            locals: { player: @player }
          )
        }
        format.html {
          render partial: "edit_info_modal", locals: { player: @player }, status: :unprocessable_entity
        }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { success: false, error: "Jugador no encontrado" } }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("edit_info_modal_content", "")
      }
      format.html { redirect_to players_path, alert: "Jugador no encontrado" }
    end
  end

  def edit_teams
    @player = Player.find(params[:id])
    @teams = Team.order(:name)

    respond_to do |format|
      format.html { render partial: "edit_teams_modal" }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("edit_teams_modal_content",
          partial: "edit_teams_modal"
        )
      }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to players_path, alert: "Jugador no encontrado" }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("edit_teams_modal_content", "")
      }
    end
  end

  def update_teams
    @player = Player.find(params[:id])
    
    team_ids = params[:team_ids]&.reject(&:blank?) || []
    primary_team_id = params[:primary_team_id]

    if @player.assign_teams(team_ids, primary_team_id)
      respond_to do |format|
        format.json { render json: { success: true, message: "Equipos actualizados correctamente" } }
        format.turbo_stream {
          # Preparar datos para la recarga usando parámetros de la sesión
          @query = session[:players_query]
          @character_filter = session[:players_character_filter]
          @team_filter = session[:players_team_filter]
          @country_filter = session[:players_country_filter]
          @sort_by = session[:players_sort_by]
          @page = session[:players_page]
          @players = prepare_players_data

          # Construir la URL correcta para la redirección
          redirect_params = {
            query: @query,
            character_filter: @character_filter,
            team_filter: @team_filter,
            country_filter: @country_filter,
            sort_by: @sort_by,
            page: @page
          }.compact
          
          redirect_url = players_path(redirect_params)
          
          # Usar turbo_stream.action(:visit, ...) para redirección
          render turbo_stream: turbo_stream.action(:visit, redirect_url)
        }
        format.html { redirect_to players_path, notice: "Equipos actualizados correctamente" }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, error: "Error al actualizar equipos" } }
        format.turbo_stream {
          @teams = Team.order(:name)
          render turbo_stream: turbo_stream.replace("edit_teams_modal_content",
            partial: "edit_teams_modal"
          )
        }
        format.html {
          @teams = Team.order(:name)
          render partial: "edit_teams_modal", 
                 status: :unprocessable_entity
        }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { success: false, error: "Jugador no encontrado" } }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("edit_teams_modal_content", "")
      }
      format.html { redirect_to players_path, alert: "Jugador no encontrado" }
    end
  end

  private

  def player_params
    params.require(:player).permit(:character_1, :skin_1, :character_2, :skin_2, :character_3, :skin_3)
  end

  def player_info_params
    params.require(:player).permit(:entrant_name, :name, :country, :city, :state, :twitter_handle, :bio, :birthday, :gender_pronoun)
  end

  def prepare_players_data
    # Comenzar con la consulta base
    players_query = Player.all

    # Usar parámetros de la URL o de la sesión como fallback
    character_filter = params[:character_filter].presence || session[:players_character_filter]
    team_filter = params[:team_filter].presence || session[:players_team_filter]
    country_filter = params[:country_filter].presence || session[:players_country_filter]
    query = @query.presence || session[:players_query]
    sort_by = params[:sort_by].presence || session[:players_sort_by] || "recent_tournament"

    # Aplicar filtro por personaje
    if character_filter.present?
      if character_filter == "none"
        # Jugadores sin personajes asignados
        players_query = players_query.where(
          character_1: [ nil, "" ],
          character_2: [ nil, "" ],
          character_3: [ nil, "" ]
        )
      else
        # Jugadores que usan un personaje específico (en cualquier slot)
        players_query = players_query.where(
          "character_1 = ? OR character_2 = ? OR character_3 = ?",
          character_filter, character_filter, character_filter
        )
      end
    end

    # Aplicar filtro por equipo
    if team_filter.present?
      if team_filter == "none"
        # Jugadores sin equipos asignados
        players_query = players_query.left_joins(:player_teams).where(player_teams: { id: nil })
      else
        # Jugadores que pertenecen a un equipo específico
        players_query = players_query.joins(:player_teams).where(player_teams: { team_id: team_filter })
      end
    end

    # Aplicar filtro por país
    if country_filter.present?
      if country_filter == "none"
        # Jugadores sin país asignado
        players_query = players_query.where(country: [nil, ""])
      else
        # Jugadores de un país específico
        players_query = players_query.where(country: country_filter)
      end
    end

    # Solo incluir jugadores con event_seeds si no estamos filtrando por "sin personajes"
    # y si no hay filtro de personaje específico
    if character_filter != "none" && character_filter.blank?
      players_query = players_query.joins(:event_seeds).distinct
    elsif character_filter.present? && character_filter != "none"
      # Para filtros de personajes específicos, incluir todos los jugadores que usan ese personaje
      # independientemente de si tienen eventos o no
      players_query = players_query.distinct
    end

    # Filtrar por nombre si se proporciona un término de búsqueda
    if query.present?
      players_query = players_query.where(
        "LOWER(players.name) LIKE LOWER(?) OR LOWER(players.entrant_name) LIKE LOWER(?) OR LOWER(players.twitter_handle) LIKE LOWER(?)",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
    end

    # CORREGIDO: Cargar TODOS los jugadores filtrados con sus asociaciones y calcular datos
    # NO aplicar paginación todavía
    all_filtered_players = Player.includes(event_seeds: { event: :tournament }, player_teams: {}, teams: {})
                                 .where(id: players_query.select(:id))
                                 .map do |player|
      # Calcular datos en Ruby para evitar problemas de SQL
      event_seeds = player.event_seeds.to_a
      tournament_dates = event_seeds.map { |es| es.event&.tournament&.start_at }.compact
      latest_date = tournament_dates.max
      oldest_date = tournament_dates.min
      events_count = event_seeds.size
      tournaments_count = event_seeds.map { |es| es.event&.tournament&.id }.compact.uniq.size

      # Agregar atributos virtuales para ordenamiento
      player.define_singleton_method(:latest_tournament_date) { latest_date }
      player.define_singleton_method(:oldest_tournament_date) { oldest_date }
      player.define_singleton_method(:events_count) { events_count }
      player.define_singleton_method(:tournaments_count) { tournaments_count }
      player
    end

    # CORREGIDO: Aplicar ordenamiento a TODOS los jugadores filtrados
    all_sorted_players = apply_sorting(all_filtered_players, sort_by)

    # CORREGIDO: Ahora sí aplicar paginación después del ordenamiento
    page = (params[:page].presence || session[:players_page] || 1).to_i
    per_page = 50
    total_count = all_sorted_players.size

    # Aplicar paginación manual
    start_index = (page - 1) * per_page
    end_index = start_index + per_page - 1
    paginated_players = all_sorted_players[start_index..end_index] || []

    # Simular la paginación de Kaminari con los datos ya ordenados y paginados
    Kaminari.paginate_array(paginated_players, total_count: total_count)
            .page(page).per(per_page)
  end

  def apply_sorting(players_array, sort_by)
    players_array.sort! do |a, b|
      case sort_by
      when "tag_asc"
        (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      when "tag_desc"
        (b.entrant_name || "").downcase <=> (a.entrant_name || "").downcase
      when "events_count_desc"
        comparison = b.events_count <=> a.events_count
        comparison != 0 ? comparison : (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      when "events_count_asc"
        comparison = a.events_count <=> b.events_count
        comparison != 0 ? comparison : (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      when "tournaments_count_desc"
        comparison = b.tournaments_count <=> a.tournaments_count
        comparison != 0 ? comparison : (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      when "tournaments_count_asc"
        comparison = a.tournaments_count <=> b.tournaments_count
        comparison != 0 ? comparison : (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      when "oldest_tournament"
        date_a = a.oldest_tournament_date || Time.at(0)
        date_b = b.oldest_tournament_date || Time.at(0)
        comparison = date_a <=> date_b
        comparison != 0 ? comparison : (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      when "recent_tournament"
        date_a = a.latest_tournament_date || Time.at(0)
        date_b = b.latest_tournament_date || Time.at(0)
        comparison = date_b <=> date_a
        comparison != 0 ? comparison : (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      else
        # Por defecto: más reciente inscripción
        date_a = a.latest_tournament_date || Time.at(0)
        date_b = b.latest_tournament_date || Time.at(0)
        comparison = date_b <=> date_a
        comparison != 0 ? comparison : (a.entrant_name || "").downcase <=> (b.entrant_name || "").downcase
      end
    end

    players_array
  end
end
