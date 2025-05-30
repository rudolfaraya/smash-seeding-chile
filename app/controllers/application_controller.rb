class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Incluir Pundit
  include Pundit::Authorization
  
  # Rescatar errores de autorización
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  protected
  
  # Método helper para verificar si el usuario puede realizar acciones de administración
  def require_authentication_for_admin_actions
    unless user_signed_in?
      respond_to do |format|
        format.html { 
          redirect_to new_user_session_path, 
                      alert: "Debes iniciar sesión para realizar esta acción" 
        }
        format.json { 
          render json: { 
            success: false, 
            error: "Autenticación requerida" 
          }, status: :unauthorized 
        }
        format.turbo_stream {
          flash.now[:alert] = "Debes iniciar sesión para realizar esta acción"
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        }
      end
    end
  end
  
  private
  
  # Manejo de errores de autorización de Pundit
  def user_not_authorized
    flash[:alert] = "No tienes permisos para realizar esta acción."
    redirect_back(fallback_location: root_path)
  end
end
