class UserPlayerRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_player_request, only: [:show, :cancel]
  before_action :ensure_can_request, only: [:new, :create]

  def index
    authorize UserPlayerRequest
    @requests = current_user.user_player_requests.recent.includes(:player)
    @pending_request = current_user.pending_player_request
  end

  def show
    authorize @request
    # Mostrar detalles de la solicitud
  end

  def new
    authorize UserPlayerRequest
    @request = current_user.user_player_requests.build
    @suggested_players = find_suggested_players
  end

  def create
    authorize UserPlayerRequest
    @request = current_user.user_player_requests.build(user_player_request_params)
    
    if @request.save
      flash[:success] = "Solicitud enviada correctamente. Un administrador la revisará pronto."
      redirect_to user_player_requests_path
    else
      @suggested_players = find_suggested_players
      flash.now[:alert] = "Error al enviar la solicitud: #{@request.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    authorize @request, :cancel?
    if @request.can_be_modified?
      @request.destroy
      flash[:success] = "Solicitud cancelada correctamente."
    else
      flash[:alert] = "No puedes cancelar esta solicitud."
    end
    redirect_to user_player_requests_path
  end

  # Búsqueda AJAX para players
  def search_players
    authorize UserPlayerRequest, :search_players?
    
    query = params[:query]&.strip
    
    if query.blank? || query.length < 2
      render json: { players: [] }
      return
    end
    
    begin
      players = Player.where(
        "LOWER(entrant_name) LIKE ? OR LOWER(name) LIKE ?", 
        "%#{query.downcase}%", 
        "%#{query.downcase}%"
      )
      .where.not(id: UserPlayerRequest.pending.select(:player_id)) # Excluir players con solicitudes pendientes
      .where.not(id: User.where.not(player_id: nil).select(:player_id)) # Excluir players ya vinculados
      .limit(20)

      players_data = players.map do |player|
        {
          id: player.id,
          entrant_name: player.entrant_name,
          name: player.name,
          display_name: "#{player.entrant_name || 'Sin tag'} (#{player.name || 'Sin nombre'})",
          tournaments_count: player.events.joins(:tournament).distinct.count,
          events_count: player.events.count
        }
      end

      Rails.logger.info "Búsqueda de jugadores: query='#{query}', encontrados=#{players_data.length}"

      render json: {
        players: players_data,
        query: query,
        count: players_data.length
      }
    rescue => e
      Rails.logger.error "Error en búsqueda de jugadores: #{e.message}"
      render json: { 
        error: "Error interno del servidor", 
        players: [] 
      }, status: :internal_server_error
    end
  end

  # Acción temporal para debug
  def debug
    # Sin autorización para facilitar el debug
  end

  private

  def set_user_player_request
    @request = current_user.user_player_requests.find(params[:id])
  end

  def ensure_can_request
    unless current_user.can_request_player_link?
      flash[:alert] = if current_user.has_linked_player?
        "Ya tienes un jugador vinculado a tu cuenta."
      else
        "Ya tienes una solicitud pendiente."
      end
      redirect_to user_player_requests_path
    end
  end

  def find_suggested_players
    # Buscar players similares al email/nombre del usuario
    email_parts = current_user.email.split('@').first.split(/[._-]/)
    username_parts = current_user.startgg_username&.split(/[._-]/) || []
    all_parts = (email_parts + username_parts).uniq.select { |part| part.length >= 3 }

    return Player.none if all_parts.empty?

    query_conditions = all_parts.map { "LOWER(entrant_name) LIKE ? OR LOWER(name) LIKE ?" }.join(" OR ")
    query_values = all_parts.flat_map { |part| ["%#{part.downcase}%", "%#{part.downcase}%"] }

    Player.where(query_conditions, *query_values)
          .where.not(id: UserPlayerRequest.pending.select(:player_id))
          .where.not(id: User.where.not(player_id: nil).select(:player_id))
          .limit(10)
  end

  def user_player_request_params
    params.require(:user_player_request).permit(:player_id, :message)
  end
end 