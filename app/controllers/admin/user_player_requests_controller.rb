class Admin::UserPlayerRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_user_player_request, only: [:show, :approve, :reject]

  def index
    @pending_requests = UserPlayerRequest.for_admin_review.includes(:user, :player)
    @recent_requests = UserPlayerRequest.where.not(status: :pending)
                                       .recent
                                       .includes(:user, :player)
                                       .limit(20)
  end

  def show
    # Mostrar detalles de la solicitud para revisión
  end

  def approve
    response_message = params[:admin_response]&.strip
    
    begin
      @request.approve!(current_user, response_message)
      flash[:success] = "Solicitud aprobada correctamente. El usuario #{@request.user.display_name} ahora puede editar su perfil de jugador."
    rescue StandardError => e
      flash[:alert] = "Error al aprobar la solicitud: #{e.message}"
    end
    
    redirect_to admin_user_player_requests_path
  end

  def reject
    response_message = params[:admin_response]&.strip
    
    if response_message.blank?
      flash[:alert] = "Debes proporcionar una razón para rechazar la solicitud."
      redirect_to admin_user_player_request_path(@request)
      return
    end
    
    begin
      @request.reject!(current_user, response_message)
      flash[:success] = "Solicitud rechazada. El usuario #{@request.user.display_name} ha sido notificado."
    rescue StandardError => e
      flash[:alert] = "Error al rechazar la solicitud: #{e.message}"
    end
    
    redirect_to admin_user_player_requests_path
  end

  # Vista rápida para revisar múltiples solicitudes
  def bulk_review
    @requests = UserPlayerRequest.pending.includes(:user, :player)
  end

  # Estadísticas para el dashboard de admin
  def stats
    @stats = {
      pending_count: UserPlayerRequest.pending.count,
      approved_today: UserPlayerRequest.approved.where('responded_at >= ?', 1.day.ago).count,
      rejected_today: UserPlayerRequest.rejected.where('responded_at >= ?', 1.day.ago).count,
      total_linked_users: User.where.not(player_id: nil).count,
      users_without_player: User.where(player_id: nil, role: :user).count
    }
    
    render json: @stats
  end

  private

  def set_user_player_request
    @request = UserPlayerRequest.find(params[:id])
  end

  def ensure_admin!
    unless current_user.admin?
      flash[:alert] = "No tienes permisos para acceder a esta sección."
      redirect_to root_path
    end
  end
end 