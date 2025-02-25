class Tournament < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :event_seeds, through: :events
  has_many :players, through: :event_seeds

  def fetch_and_save_events
    # Verificar si ya hay eventos para este torneo
    return if events.any?

    Rails.logger.info "Sincronizando eventos para el torneo: #{name} (Fecha: #{start_at})"
    begin
      # Crear una instancia de StartGgClient para las consultas a la API
      client = StartGgClient.new

      # Obtener eventos desde la API usando StartGgQueries
      events_data = StartGgQueries.fetch_tournament_events(client, slug)

      # Guardar cada evento en la base de datos
      events_data.each do |event_data|
        Event.find_or_create_by(tournament: self, slug: event_data['slug']) do |event|
          event.name = event_data['name']
          event.id = event_data['id']
        end
        Rails.logger.info "Evento guardado: #{event_data['name']} (ID: #{event_data['id']})"
      end
    rescue Faraday::ClientError => e
      if e.response[:status] == 429
        Rails.logger.warn "Rate limit excedido para torneo #{slug}. Esperando 60 segundos..."
        sleep(60) # Espera 60 segundos antes de reintentar
        retry
      elsif [404, 500].include?(e.response[:status])
        Rails.logger.error "Error HTTP #{e.response[:status]} al obtener eventos para torneo #{slug}: #{e.response[:body]}"
        raise "Error HTTP al obtener eventos: #{e.response[:status]} - #{e.response[:body]}"
      else
        Rails.logger.error "Error al obtener eventos para torneo #{slug}: #{e.message}"
        raise
      end
    rescue StandardError => e
      Rails.logger.error "Error procesando eventos para torneo #{name}: #{e.message}"
      raise
    end
    sleep 5 # Retraso para respetar los límites de rate limiting (80 solicitudes/minuto)
  end
end
