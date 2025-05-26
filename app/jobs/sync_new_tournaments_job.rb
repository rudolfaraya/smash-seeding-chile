class SyncNewTournamentsJob < ApplicationJob
  queue_as :high_priority

  def perform(options = {})
    Rails.logger.info "🆕 Iniciando sincronización de nuevos torneos"
    
    service = SyncSmashData.new
    nuevos_torneos = service.sync_tournaments_and_events_atomic
    
    Rails.logger.info "✅ Sincronización de nuevos torneos completada: #{nuevos_torneos} torneos agregados"
    
    { status: 'success', nuevos_torneos: nuevos_torneos }
  rescue StandardError => e
    Rails.logger.error "❌ Error en sincronización de nuevos torneos: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 