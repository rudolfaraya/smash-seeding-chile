VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
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
  
  # Allow real HTTP connections when not using VCR
  config.allow_http_connections_when_no_cassette = false
end 