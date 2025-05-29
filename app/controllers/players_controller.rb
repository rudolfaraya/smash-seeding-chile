class PlayersController < ApplicationController
  # Requerir autenticación para update_smash_characters y update_info
  before_action :authenticate_user!, only: [:update_smash_characters, :update_info]
  before_action :set_filter_params, only: [:index]

  def index
    Rails.logger.info "=== Players#index called with query: '#{@query}', character_filter: '#{@character_filter}', team_filter: '#{@team_filter}', country_filter: '#{@country_filter}', sort_by: '#{@sort_by}', page: '#{@page}', format: #{request.format} ==="

    # Guardar todos los parámetros de filtro en la sesión
    save_filter_params_to_session

    # Usar el servicio para obtener los jugadores filtrados
    @players = PlayersFilterService.new(params, session).call

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
      # CACHÉ: Invalidar caché después de actualizar personajes
      PlayersFilterService.invalidate_cache
      
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
          @players = PlayersFilterService.new(params, session).call

          # Construir la URL correcta para la redirección
          redirect_params = build_redirect_params
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
      # CACHÉ: Invalidar caché después de actualizar información
      PlayersFilterService.invalidate_cache
      
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
          @players = PlayersFilterService.new(params, session).call

          # Construir la URL correcta para la redirección
          redirect_params = build_redirect_params
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
      # CACHÉ: Invalidar caché después de actualizar equipos
      PlayersFilterService.invalidate_cache
      
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
          @players = PlayersFilterService.new(params, session).call

          # Construir la URL correcta para la redirección
          redirect_params = build_redirect_params
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

  def set_filter_params
    @query = params[:query]
    @character_filter = params[:character_filter]
    @team_filter = params[:team_filter]
    @country_filter = params[:country_filter]
    @sort_by = params[:sort_by]
    @page = params[:page]
  end

  def save_filter_params_to_session
    session[:players_query] = @query
    session[:players_character_filter] = @character_filter
    session[:players_team_filter] = @team_filter
    session[:players_country_filter] = @country_filter
    session[:players_sort_by] = @sort_by
    session[:players_page] = @page
  end

  def build_redirect_params
    {
      query: @query,
      character_filter: @character_filter,
      team_filter: @team_filter,
      country_filter: @country_filter,
      sort_by: @sort_by,
      page: @page
    }.compact
  end
end
