VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = {
    record: :none,
    match_requests_on: [ :method, :uri, :body ]
  }

  # Filter sensitive data
  config.filter_sensitive_data('<START_GG_API_TOKEN>') { ENV['START_GG_API_TOKEN'] }
  config.filter_sensitive_data('<AUTHORIZATION_HEADER>') { |interaction|
    interaction.request.headers['Authorization']&.first
  }

  # Configure for different environments
  config.configure_rspec_metadata!

  # Allow localhost connections for development
  config.ignore_localhost = true

  # Deshabilitar conexiones HTTP reales - los tests deben usar mocks/stubs
  config.allow_http_connections_when_no_cassette = false

  # Configurar hosts ignorados para desarrollo local
  config.ignore_hosts 'localhost', '127.0.0.1', '0.0.0.0'

  # Configurar para que falle si intenta hacer una llamada real sin cassette
  config.default_cassette_options[:record] = :none

  # Configuración específica para tests que requieren cassettes existentes
  config.before_record do |interaction|
    # Solo permitir grabación en modo de desarrollo explícito
    if ENV['VCR_RECORD_MODE'] != 'true'
      raise "Intento de grabación de cassette detectado. Si necesitas grabar nuevos cassettes, ejecuta con VCR_RECORD_MODE=true"
    end
  end
end
