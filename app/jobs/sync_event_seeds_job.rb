class SyncEventSeedsJob < ApplicationJob
  queue_as :default

  def perform(event_id, options = {})
    Rails.logger.info "🌱 INICIANDO SINCRONIZACIÓN DE SEEDS"
    Rails.logger.info "   Evento ID: #{event_id}"
    Rails.logger.info "   Opciones: #{options}"

    event = Event.find(event_id)
    update_players = options[:update_players] || false

    Rails.logger.info "   Evento: #{event.name}"
    Rails.logger.info "   Torneo: #{event.tournament.name}"
    Rails.logger.info "   Update Players: #{update_players}"
    Rails.logger.info "   Seeds existentes: #{event.event_seeds.count}"

    # Usar el servicio de sincronización de seeds
    Rails.logger.info "🔄 Llamando al servicio SyncEventSeeds..."
    sync_service = SyncEventSeeds.new(event, update_players: update_players)
    sync_service.call

    # Actualizar timestamp de sincronización
    if event.respond_to?(:seeds_last_synced_at)
      event.update(seeds_last_synced_at: Time.current)
      Rails.logger.info "   ⏰ Timestamp actualizado: #{Time.current}"
    end

    # Recargar para obtener datos actualizados
    event.reload
    seeds_count = event.event_seeds.count
    Rails.logger.info "✅ SINCRONIZACIÓN COMPLETADA"
    Rails.logger.info "   Seeds finales: #{seeds_count}"
    Rails.logger.info "   Status: SUCCESS"

    {
      status: "success",
      event_id: event_id,
      event_name: event.name,
      tournament_name: event.tournament.name,
      seeds_count: seeds_count,
      update_players: update_players
    }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ EVENTO NO ENCONTRADO"
    Rails.logger.error "   Evento ID: #{event_id}"
    Rails.logger.error "   Error: #{e.message}"
    raise
  rescue StandardError => e
    Rails.logger.error "❌ ERROR EN SINCRONIZACIÓN DE SEEDS"
    Rails.logger.error "   Evento ID: #{event_id}"
    Rails.logger.error "   Error: #{e.message}"
    Rails.logger.error "   Backtrace: #{e.backtrace.first(5).join('\n')}"
    raise
  end
end
