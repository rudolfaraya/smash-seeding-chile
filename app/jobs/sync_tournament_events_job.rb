class SyncTournamentEventsJob < ApplicationJob
  queue_as :default

  def perform(tournament_id, options = {})
    Rails.logger.info "📋 Iniciando sincronización de eventos para torneo ID: #{tournament_id}"
    
    tournament = Tournament.find(tournament_id)
    service = SyncSmashData.new
    nuevos_eventos = service.sync_events_for_single_tournament(tournament)
    
    Rails.logger.info "✅ Sincronización de eventos completada para #{tournament.name}: #{nuevos_eventos} eventos"
    
    { 
      status: 'success', 
      tournament_id: tournament_id, 
      tournament_name: tournament.name,
      nuevos_eventos: nuevos_eventos 
    }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ Torneo no encontrado ID: #{tournament_id}"
    raise
  rescue StandardError => e
    Rails.logger.error "❌ Error sincronizando eventos del torneo #{tournament_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 