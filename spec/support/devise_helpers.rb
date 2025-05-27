module DeviseHelpers
  # Helper para iniciar sesión en tests de request
  def sign_in_user(user = nil)
    user ||= create(:user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: user.password
      }
    }
    user
  end

  # Helper para cerrar sesión en tests de request
  def sign_out_user
    delete destroy_user_session_path
  end

  # Helper para verificar si un usuario está autenticado
  def user_signed_in?
    session[:user_id].present?
  end

  # Helper para obtener el usuario actual de la sesión
  def current_user
    return nil unless session[:user_id]
    User.find(session[:user_id])
  end

  # Helper para simular confirmación de email
  def confirm_user(user)
    user.update!(
      confirmed_at: Time.current,
      confirmation_token: nil
    )
  end

  # Helper para simular bloqueo de cuenta
  def lock_user(user)
    user.update!(
      locked_at: Time.current,
      failed_attempts: 5,
      unlock_token: SecureRandom.hex(10)
    )
  end

  # Helper para simular reset de contraseña
  def reset_password_for(user)
    user.update!(
      reset_password_token: SecureRandom.hex(10),
      reset_password_sent_at: Time.current
    )
  end
end

RSpec.configure do |config|
  config.include DeviseHelpers, type: :request
  config.include DeviseHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
end 