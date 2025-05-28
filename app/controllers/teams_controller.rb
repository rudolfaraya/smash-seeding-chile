class TeamsController < ApplicationController
  def index
    @query = params[:query]
    @sort_by = params[:sort_by] || "name_asc"
    @page = params[:page]

    Rails.logger.info "=== Teams#index called with query: '#{@query}', sort_by: '#{@sort_by}', page: '#{@page}', format: #{request.format} ==="

    # Guardar parámetros en la sesión
    session[:teams_query] = @query
    session[:teams_sort_by] = @sort_by
    session[:teams_page] = @page

    # Preparar datos de equipos
    @teams = prepare_teams_data

    Rails.logger.info "=== Found #{@teams.size} teams, responding with format: #{request.format} ==="

    respond_to do |format|
      format.html do
        Rails.logger.info "=== Responding with HTML ==="
        if params[:partial] == "true" || turbo_frame_request?
          Rails.logger.info "=== Rendering partial for Turbo Frame ==="
          render partial: "teams_list", locals: { teams: @teams }
        else
          Rails.logger.info "=== Rendering full page ==="
          render :index
        end
      end
      format.turbo_stream { Rails.logger.info "=== Responding with TURBO_STREAM ===" }
    end
  end

  def show
    @team = Team.find(params[:id])
    
    # Obtener jugadores del equipo con información adicional
    team_players = @team.players_with_primary_info.includes(:event_seeds, :events)
    
    # Calcular estadísticas adicionales para cada jugador
    @players = team_players.map do |player|
      # Agregar conteos de eventos y torneos
      events_count = player.event_seeds.count
      tournaments_count = player.event_seeds.joins(:event).distinct.count('events.tournament_id')
      
      # Crear un hash con la información del jugador
      # El atributo is_primary viene del select de SQL
      {
        id: player.id,
        entrant_name: player.entrant_name,
        name: player.name,
        is_primary: player.is_primary,
        events_count: events_count,
        tournaments_count: tournaments_count
      }
    end
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          success: true,
          team: {
            id: @team.id,
            name: @team.name,
            acronym: @team.acronym,
            description: @team.description,
            players_count: @team.players_count
          },
          players: @players
        }
      end
    end
  end

  def search
    redirect_to teams_path(query: params[:query])
  end

  def new
    @team = Team.new
    
    respond_to do |format|
      format.html { render :new }
      format.json { render json: { success: true } }
    end
  end

  def create
    @team = Team.new(team_params)
    
    if @team.save
      respond_to do |format|
        format.html { redirect_to @team, notice: 'Equipo creado exitosamente.' }
        format.json { 
          render json: { 
            success: true, 
            message: 'Equipo creado exitosamente',
            team: {
              id: @team.id,
              name: @team.name,
              acronym: @team.acronym,
              description: @team.description
            },
            redirect_url: team_path(@team)
          }
        }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { 
          render json: { 
            success: false, 
            errors: @team.errors.full_messages 
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def edit
    @team = Team.find(params[:id])
    
    respond_to do |format|
      format.html { render :edit }
      format.json { render json: { success: true, team: @team } }
    end
  end

  def update
    @team = Team.find(params[:id])
    
    # Manejar eliminación del logo si se solicita
    if params[:team][:remove_logo] == 'true'
      @team.logo_image.purge if @team.logo_image.attached?
    end
    
    # Filtrar el parámetro remove_logo antes de actualizar
    update_params = team_params.except(:remove_logo)
    
    if @team.update(update_params)
      respond_to do |format|
        format.html { redirect_to @team, notice: 'Equipo actualizado exitosamente.' }
        format.json { 
          render json: { 
            success: true, 
            message: 'Equipo actualizado exitosamente',
            team: {
              id: @team.id,
              name: @team.name,
              acronym: @team.acronym,
              description: @team.description
            }
          }
        }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { 
          render json: { 
            success: false, 
            errors: @team.errors.full_messages 
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def destroy
    @team = Team.find(params[:id])
    team_name = @team.name
    players_count = @team.players_count
    
    if @team.destroy
      respond_to do |format|
        format.html { 
          redirect_to teams_path, 
          notice: "Equipo '#{team_name}' eliminado exitosamente. Se removieron #{players_count} asociaciones de jugadores." 
        }
        format.json { 
          render json: { 
            success: true, 
            message: "Equipo '#{team_name}' eliminado exitosamente",
            players_removed: players_count,
            redirect_url: teams_path
          }
        }
      end
    else
      respond_to do |format|
        format.html { 
          redirect_to @team, 
          alert: 'Error al eliminar el equipo.' 
        }
        format.json { 
          render json: { 
            success: false, 
            error: 'Error al eliminar el equipo' 
          }, status: :unprocessable_entity
        }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { 
        redirect_to teams_path, 
        alert: 'Equipo no encontrado.' 
      }
      format.json { 
        render json: { 
          success: false, 
          error: 'Equipo no encontrado' 
        }, status: :not_found
      }
    end
  end

  def add_player
    @team = Team.find(params[:id])
    player_id = params[:player_id]
    is_primary = params[:is_primary] == 'true'

    if @team.add_player(player_id, is_primary)
      render json: { 
        success: true, 
        message: "Jugador agregado al equipo correctamente",
        reload_team: true
      }
    else
      render json: { 
        success: false, 
        error: "Error al agregar el jugador al equipo" 
      }
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { 
      success: false, 
      error: e.message.include?("Team") ? "Equipo no encontrado" : "Jugador no encontrado"
    }
  end

  def remove_player
    @team = Team.find(params[:id])
    player_id = params[:player_id]

    if @team.remove_player(player_id)
      render json: { 
        success: true, 
        message: "Jugador removido del equipo correctamente",
        reload_team: true
      }
    else
      render json: { 
        success: false, 
        error: "Error al remover el jugador del equipo" 
      }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { 
      success: false, 
      error: "Equipo no encontrado" 
    }
  end

  def search_players
    @team = Team.find(params[:id])
    search_term = params[:search]
    
    players = @team.available_players(search_term)
    
    players_data = players.map do |player|
      {
        id: player.id,
        entrant_name: player.entrant_name || "Sin tag",
        name: player.name || "Sin nombre",
        display_name: "#{player.entrant_name || 'Sin tag'} (#{player.name || 'Sin nombre'})"
      }
    end
    
    render json: { 
      success: true, 
      players: players_data 
    }
  rescue ActiveRecord::RecordNotFound
    render json: { 
      success: false, 
      error: "Equipo no encontrado" 
    }
  end

  private

  def prepare_teams_data
    # Comenzar con la consulta base
    base_query = Team.all

    # Usar parámetros de la URL o de la sesión como fallback
    query = params[:query].presence || session[:teams_query]
    sort_by = params[:sort_by].presence || session[:teams_sort_by]

    # Filtrar por nombre si se proporciona un término de búsqueda
    if query.present?
      base_query = base_query.where(
        "LOWER(teams.name) LIKE LOWER(?) OR LOWER(teams.acronym) LIKE LOWER(?)",
        "%#{query}%", "%#{query}%"
      )
    end

    # Aplicar paginación
    page = (params[:page].presence || session[:teams_page] || 1).to_i
    per_page = 20

    # Calcular el total count con la consulta base
    total_count = base_query.count

    # Obtener los equipos con conteo de jugadores
    teams_with_data = base_query.with_players_count.to_a

    # Aplicar ordenamiento
    teams_with_data = apply_sorting(teams_with_data, sort_by)

    # Simular la paginación de Kaminari
    Kaminari.paginate_array(teams_with_data, total_count: total_count)
            .page(page).per(per_page)
  end

  def apply_sorting(teams_array, sort_by)
    teams_array.sort! do |a, b|
      case sort_by
      when "name_asc"
        a.name.downcase <=> b.name.downcase
      when "name_desc"
        b.name.downcase <=> a.name.downcase
      when "acronym_asc"
        a.acronym.downcase <=> b.acronym.downcase
      when "acronym_desc"
        b.acronym.downcase <=> a.acronym.downcase
      when "players_count_desc"
        comparison = b.players_count <=> a.players_count
        comparison != 0 ? comparison : a.name.downcase <=> b.name.downcase
      when "players_count_asc"
        comparison = a.players_count <=> b.players_count
        comparison != 0 ? comparison : a.name.downcase <=> b.name.downcase
      when "created_desc"
        comparison = b.created_at <=> a.created_at
        comparison != 0 ? comparison : a.name.downcase <=> b.name.downcase
      when "created_asc"
        comparison = a.created_at <=> b.created_at
        comparison != 0 ? comparison : a.name.downcase <=> b.name.downcase
      else
        # Por defecto: nombre ascendente
        a.name.downcase <=> b.name.downcase
      end
    end

    teams_array
  end

  def team_params
    params.require(:team).permit(:name, :acronym, :description, :logo_image, :remove_logo)
  end
end
