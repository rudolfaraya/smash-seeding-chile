class SyncAllTournamentsJob < ApplicationJob
  queue_as :low_priority

  def perform(options = {})
    Rails.logger.info "🚀 Iniciando sincronización masiva de torneos"
    
    limit = options[:limit]
    force = options[:force] || false
    
    # Identificar torneos que necesitan sincronización
    torneos_sin_eventos = Tournament.left_joins(:events)
                                  .where(events: { id: nil })
                                  .order(start_at: :desc)
                                  
    torneos_con_eventos_sin_seeds = Tournament.joins(:events)
                                            .where.not(id: Tournament.joins(events: :event_seeds)
                                                                   .distinct.pluck(:id))
                                            .distinct
                                            .order(start_at: :desc)
    
    # Aplicar límite si se especifica
    if limit
      torneos_sin_eventos = torneos_sin_eventos.limit(limit)
      torneos_con_eventos_sin_seeds = torneos_con_eventos_sin_seeds.limit(limit)
    end
    
    total_torneos = (torneos_sin_eventos.pluck(:id) + torneos_con_eventos_sin_seeds.pluck(:id)).uniq.count
    Rails.logger.info "📊 Torneos a procesar: #{total_torneos}"
    
    results = {
      total_procesados: 0,
      exitosos: 0,
      fallidos: 0,
      detalles: []
    }
    
    # Procesar torneos sin eventos
    torneos_sin_eventos.find_each do |tournament|
      begin
        Rails.logger.info "🏆 Procesando torneo sin eventos: #{tournament.name}"
        
        job_result = SyncTournamentJob.perform_now(tournament.id, options)
        
        results[:total_procesados] += 1
        results[:exitosos] += 1
        results[:detalles] << {
          tournament_id: tournament.id,
          tournament_name: tournament.name,
          status: 'success',
          type: 'sin_eventos',
          result: job_result
        }
        
        # Pausa entre torneos para respetar rate limits
        sleep(5)
        
      rescue StandardError => e
        Rails.logger.error "❌ Error procesando torneo #{tournament.name}: #{e.message}"
        
        results[:total_procesados] += 1
        results[:fallidos] += 1
        results[:detalles] << {
          tournament_id: tournament.id,
          tournament_name: tournament.name,
          status: 'error',
          type: 'sin_eventos',
          error: e.message
        }
        
        # Pausa más larga en caso de error
        sleep(10)
      end
    end
    
    # Procesar torneos con eventos pero sin seeds
    torneos_con_eventos_sin_seeds.find_each do |tournament|
      # Evitar procesar torneos ya procesados
      next if results[:detalles].any? { |d| d[:tournament_id] == tournament.id }
      
      begin
        Rails.logger.info "🌱 Procesando torneo con eventos sin seeds: #{tournament.name}"
        
        seeds_results = []
        tournament.events.each do |event|
          seeds_job_result = SyncEventSeedsJob.perform_now(event.id, options)
          seeds_results << seeds_job_result
          sleep(2) unless event == tournament.events.last
        end
        
        results[:total_procesados] += 1
        results[:exitosos] += 1
        results[:detalles] << {
          tournament_id: tournament.id,
          tournament_name: tournament.name,
          status: 'success',
          type: 'sin_seeds',
          seeds_results: seeds_results
        }
        
        # Pausa entre torneos
        sleep(5)
        
      rescue StandardError => e
        Rails.logger.error "❌ Error procesando seeds del torneo #{tournament.name}: #{e.message}"
        
        results[:total_procesados] += 1
        results[:fallidos] += 1
        results[:detalles] << {
          tournament_id: tournament.id,
          tournament_name: tournament.name,
          status: 'error',
          type: 'sin_seeds',
          error: e.message
        }
        
        # Pausa más larga en caso de error
        sleep(10)
      end
    end
    
    Rails.logger.info "✅ Sincronización masiva completada: #{results[:exitosos]} exitosos, #{results[:fallidos]} fallidos de #{results[:total_procesados]} total"
    
    results
  rescue StandardError => e
    Rails.logger.error "❌ Error en sincronización masiva: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 