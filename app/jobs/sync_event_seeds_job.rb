class SyncEventSeedsJob < ApplicationJob
  queue_as :default

  def perform(event_id, options = {})
    Rails.logger.info "🌱 Iniciando sincronización de seeds para evento ID: #{event_id}"
    
    event = Event.find(event_id)
    force = options[:force] || false
    update_players = options[:update_players] || false
    
    # Usar el servicio de sincronización de seeds
    sync_service = SyncEventSeeds.new(event, force: force, update_players: update_players)
    sync_service.call
    
    # Actualizar timestamp de sincronización
    if event.respond_to?(:seeds_last_synced_at)
      event.update(seeds_last_synced_at: Time.current)
    end
    
    seeds_count = event.event_seeds.count
    Rails.logger.info "✅ Sincronización de seeds completada para #{event.name}: #{seeds_count} seeds"
    
    { 
      status: 'success', 
      event_id: event_id, 
      event_name: event.name,
      tournament_name: event.tournament.name,
      seeds_count: seeds_count,
      force: force,
      update_players: update_players
    }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ Evento no encontrado ID: #{event_id}"
    raise
  rescue StandardError => e
    Rails.logger.error "❌ Error sincronizando seeds del evento #{event_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end 