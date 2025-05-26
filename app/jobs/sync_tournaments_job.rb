class SyncTournamentsJob < ApplicationJob
  queue_as :high_priority

  def perform(options = {})
    Rails.logger.info "🏆 Iniciando sincronización general de torneos"
    
    service = SyncSmashData.new
    result = service.sync_tournaments
    
    Rails.logger.info "✅ Sincronización general de torneos completada"
    
    { status: 'success', result: result }
  rescue StandardError => e
    Rails.logger.error "❌ Error en sincronización general de torneos: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 