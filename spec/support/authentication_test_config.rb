# Configuración específica para tests de autenticación

RSpec.configure do |config|
  # Limpiar emails antes de cada test
  config.before(:each) do
    ActionMailer::Base.deliveries.clear
  end

  # Configurar tiempo para tests que usan travel
  config.include ActiveSupport::Testing::TimeHelpers

  # Configurar locale por defecto para tests
  config.before(:each) do
    I18n.locale = :es
  end

  # Configurar Devise para tests
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Configurar Warden para tests de sistema
  config.include Warden::Test::Helpers, type: :system
  config.after(:each, type: :system) { Warden.test_reset! }

  # Configurar ActionMailer para tests
  config.before(:suite) do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  # Configurar Devise para usar bcrypt con costo mínimo en tests
  config.before(:suite) do
    Devise.setup do |devise_config|
      devise_config.stretches = 1
    end
  end
end

# Helpers adicionales para tests de autenticación
module AuthenticationTestHelpers
  # Crear usuario y confirmar automáticamente
  def create_confirmed_user(attributes = {})
    user = create(:user, attributes)
    user.confirm
    user
  end

  # Crear usuario bloqueado
  def create_locked_user(attributes = {})
    user = create(:user, attributes)
    user.lock_access!
    user
  end

  # Simular múltiples intentos fallidos de login
  def simulate_failed_login_attempts(user, attempts = 5)
    attempts.times do
      user.increment(:failed_attempts)
    end
    user.lock_access! if user.failed_attempts >= 5
    user.save!
  end

  # Verificar que un email fue enviado
  def expect_email_sent(to:, subject_includes: nil)
    expect(ActionMailer::Base.deliveries).not_to be_empty
    
    email = ActionMailer::Base.deliveries.last
    expect(email.to).to include(to)
    
    if subject_includes
      expect(email.subject).to include(subject_includes)
    end
  end

  # Verificar que NO se envió email
  def expect_no_email_sent
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  # Limpiar emails
  def clear_emails
    ActionMailer::Base.deliveries.clear
  end
end

RSpec.configure do |config|
  config.include AuthenticationTestHelpers
end 