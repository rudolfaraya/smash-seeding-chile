require "dotenv/load" # Asegúrate de tener esta línea si usas dotenv
require "faraday"
require "json"

class StartGgClient
  def initialize
    @token = ENV["START_GG_API_TOKEN"] || raise("Falta START_GG_API_TOKEN en el entorno")
    @base_url = "https://api.start.gg/gql/alpha" # Igual que en tu prueba con curl
  end

  def query(query, variables = {}, operation_name = nil)
    body = {
      query: query,
      variables: variables,
      operationName: operation_name || "TournamentsInChile"
    }.to_json

    conn = Faraday.new(url: @base_url) do |faraday|
      faraday.headers["Authorization"] = "Bearer #{@token}"
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["User-Agent"] = "Ruby/Faraday" # Similar a tu prueba con curl
      faraday.request :url_encoded             # Codifica la URL si es necesario
      faraday.response :logger                # Opcional: logging detallado
      faraday.adapter Faraday.default_adapter  # Usa el adaptador predeterminado (Net::HTTP)
    end

    Rails.logger.debug "Enviando solicitud a Start.gg con URL: #{@base_url}"
    Rails.logger.debug "Enviando solicitud a Start.gg con body: #{body}"
    Rails.logger.debug "Headers: #{conn.headers}"

    response = conn.post do |req|
      req.body = body
    end

    Rails.logger.debug "Respuesta completa (cuerpo): #{response.body}"
    Rails.logger.debug "Respuesta completa (headers): #{response.headers}"
    parsed_response = JSON.parse(response.body)

    unless response.status == 200
      Rails.logger.error "Error en la API: #{response.status} - #{response.body}"
      raise "API request failed: #{response.status} - #{response.body}"
    end

    # Verificar si la respuesta es JSON válido
    begin
      parsed_response = JSON.parse(response.body)
    rescue JSON::ParserError => e
      Rails.logger.error "Error al parsear JSON: #{e.message}. Respuesta: #{response.body}"
      raise "Respuesta no es JSON válido: #{response.body}"
    end

    # Verifica si hay errores en la respuesta
    if parsed_response.key?("errors")
      Rails.logger.error "Errores en la respuesta: #{parsed_response["errors"]}"
      raise "API retornó errores: #{parsed_response["errors"].inspect}"
    end

    parsed_response
  end
end
