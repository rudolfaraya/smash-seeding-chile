class SyncTournamentJob < ApplicationJob
  queue_as :high_priority

  def perform(tournament_id, options = {})
    Rails.logger.info "🏆 Sincronizando torneo completo ID: #{tournament_id}"
    
    tournament = Tournament.find(tournament_id)
    
    # Sincronizar eventos del torneo
    events_job_result = SyncTournamentEventsJob.perform_now(tournament_id, options)
    
    # Si hay eventos, sincronizar sus seeds
    if tournament.events.any?
      Rails.logger.info "📋 Sincronizando seeds de #{tournament.events.count} eventos del torneo #{tournament.name}"
      
      seeds_results = []
      tournament.events.each do |event|
        begin
          seeds_job_result = SyncEventSeedsJob.perform_now(event.id, options)
          seeds_results << seeds_job_result
          
          # Pausa entre eventos para respetar rate limits
          sleep(2) unless event == tournament.events.last
        rescue StandardError => e
          Rails.logger.error "❌ Error sincronizando seeds del evento #{event.name}: #{e.message}"
          seeds_results << { status: 'error', event_id: event.id, error: e.message }
        end
      end
      
      total_seeds = seeds_results.sum { |r| r[:seeds_count] || 0 }
      Rails.logger.info "✅ Torneo #{tournament.name} sincronizado completamente: #{total_seeds} seeds totales"
      
      { 
        tournament_id: tournament_id, 
        status: 'success',
        events_result: events_job_result,
        seeds_results: seeds_results,
        total_seeds: total_seeds
      }
    else
      Rails.logger.info "⚠️ Torneo #{tournament.name} no tiene eventos para sincronizar seeds"
      
      { 
        tournament_id: tournament_id, 
        status: 'success',
        events_result: events_job_result,
        message: 'No events to sync seeds'
      }
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ Torneo no encontrado ID: #{tournament_id}"
    raise
  rescue StandardError => e
    Rails.logger.error "❌ Error sincronizando torneo #{tournament_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 