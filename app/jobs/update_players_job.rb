class UpdatePlayersJob < ApplicationJob
  queue_as :default

  def perform(options = {})
    Rails.logger.info "🚀 Iniciando job de actualización de jugadores"

    service = UpdatePlayersService.new(
      batch_size: options[:batch_size] || 25,
      delay_between_batches: options[:delay_between_batches] || 45.seconds,
      delay_between_requests: options[:delay_between_requests] || 2.seconds,
      force_update: options[:force_update] || false
    )

    results = service.update_players_in_batches

    Rails.logger.info "✅ Job de actualización de jugadores completado"
    Rails.logger.info "📊 Resultados: #{results[:updated]} actualizados, #{results[:failed]} fallidos de #{results[:total]} total"

    results
  rescue StandardError => e
    Rails.logger.error "❌ Error en UpdatePlayersJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
