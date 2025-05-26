class SendNotificationJob < ApplicationJob
  queue_as :default

  def perform(message, recipient_type = 'all')
    Rails.logger.info "📧 Enviando notificación: #{message} a #{recipient_type}"
    
    # Simular envío de notificación
    sleep(1)
    
    case recipient_type
    when 'all'
      # Enviar a todos los usuarios
      Rails.logger.info "📢 Notificación enviada a todos los usuarios"
    when 'admins'
      # Enviar solo a administradores
      Rails.logger.info "👑 Notificación enviada a administradores"
    else
      # Enviar a usuario específico
      Rails.logger.info "👤 Notificación enviada a #{recipient_type}"
    end
    
    { message: message, recipient: recipient_type, sent_at: Time.current }
  rescue StandardError => e
    Rails.logger.error "❌ Error enviando notificación: #{e.message}"
    raise
  end
end 