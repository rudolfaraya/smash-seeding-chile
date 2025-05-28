class SyncLatestTournamentsJob < ApplicationJob
  queue_as :high_priority

  def perform(options = {})
    limit = options[:limit] || 20
    force = options[:force] || true
    
    Rails.logger.info "🔄 Iniciando actualización forzada de los últimos #{limit} torneos"
    
    # Obtener los últimos torneos ordenados por fecha de inicio
    latest_tournaments = Tournament.order(start_at: :desc).limit(limit)
    
    results = {
      total_procesados: 0,
      exitosos: 0,
      fallidos: 0,
      detalles: []
    }
    
    Rails.logger.info "📊 Torneos a actualizar: #{latest_tournaments.count}"
    
    latest_tournaments.each_with_index do |tournament, index|
      begin
        Rails.logger.info "🏆 Actualizando torneo #{index + 1}/#{latest_tournaments.count}: #{tournament.name}"
        
        # Usar SyncTournamentJob con force = true para forzar actualización completa
        job_result = SyncTournamentJob.perform_now(tournament.id, { force: force })
        
        results[:total_procesados] += 1
        results[:exitosos] += 1
        results[:detalles] << {
          tournament_id: tournament.id,
          tournament_name: tournament.name,
          status: 'success',
          result: job_result
        }
        
        Rails.logger.info "✅ Torneo actualizado exitosamente: #{tournament.name}"
        
        # Pausa entre torneos para respetar rate limits
        sleep(4) unless index == latest_tournaments.count - 1
        
      rescue StandardError => e
        Rails.logger.error "❌ Error actualizando torneo #{tournament.name}: #{e.message}"
        
        results[:total_procesados] += 1
        results[:fallidos] += 1
        results[:detalles] << {
          tournament_id: tournament.id,
          tournament_name: tournament.name,
          status: 'error',
          error: e.message
        }
        
        # Pausa más larga en caso de error
        sleep(8)
      end
    end
    
    Rails.logger.info "✅ Actualización forzada completada: #{results[:exitosos]} exitosos, #{results[:fallidos]} fallidos de #{results[:total_procesados]} total"
    
    results
  rescue StandardError => e
    Rails.logger.error "❌ Error en actualización forzada de torneos: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 