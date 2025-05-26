class UpdatePlayersService
  def initialize(options = {})
    @batch_size = options[:batch_size] || 50
    @delay_between_batches = options[:delay_between_batches] || 30.seconds
    @delay_between_requests = options[:delay_between_requests] || 1.second
    @force_update = options[:force_update] || false
  end

  # Actualizar jugadores en lotes para evitar rate limits
  def update_players_in_batches
    Rails.logger.info "🚀 Iniciando actualización de jugadores en lotes"

    players_to_update = get_players_to_update
    total_players = players_to_update.count

    Rails.logger.info "📊 Total de jugadores a actualizar: #{total_players}"

    return { success: true, message: "No hay jugadores para actualizar" } if total_players == 0

    results = {
      total: total_players,
      updated: 0,
      failed: 0,
      skipped: 0,
      batches_processed: 0
    }

    batch_index = 0
    players_to_update.in_batches(of: @batch_size) do |batch|
      batch_index += 1
      Rails.logger.info "🔄 Procesando lote #{batch_index} (#{batch.count} jugadores)"

      batch_results = process_batch(batch)

      results[:updated] += batch_results[:updated]
      results[:failed] += batch_results[:failed]
      results[:skipped] += batch_results[:skipped]
      results[:batches_processed] += 1

      # Pausa entre lotes para evitar rate limits
      total_batches = (total_players.to_f / @batch_size).ceil
      if batch_index < total_batches
        Rails.logger.info "⏸️ Pausa de #{@delay_between_batches} segundos entre lotes"
        sleep(@delay_between_batches)
      end
    end

    Rails.logger.info "🎉 Actualización completada: #{results[:updated]} actualizados, #{results[:failed]} fallidos"
    results
  end

  # Actualizar jugadores cuando se sincronizan nuevos torneos
  def update_players_from_tournament_sync(tournament)
    Rails.logger.info "🔄 Actualizando jugadores del torneo: #{tournament.name}"

    # Obtener jugadores únicos del torneo
    player_ids = tournament.events
                          .joins(:event_seeds)
                          .pluck("event_seeds.player_id")
                          .uniq

    players = Player.where(id: player_ids)

    results = {
      total: players.count,
      updated: 0,
      failed: 0,
      skipped: 0
    }

    players.find_each do |player|
      begin
        if player.needs_update? || @force_update
          if player.update_from_start_gg_api
            results[:updated] += 1
            Rails.logger.info "✅ Actualizado: #{player.entrant_name}"
          else
            results[:failed] += 1
          end
        else
          results[:skipped] += 1
          Rails.logger.info "⏭️ Saltado (actualizado recientemente): #{player.entrant_name}"
        end

        sleep(@delay_between_requests)

      rescue StandardError => e
        results[:failed] += 1
        Rails.logger.error "❌ Error actualizando #{player.entrant_name}: #{e.message}"
        sleep(@delay_between_requests * 2) # Pausa más larga en caso de error
      end
    end

    Rails.logger.info "✅ Actualización del torneo completada: #{results[:updated]} actualizados"
    results
  end

  # Actualizar jugadores cuando se fuerza la sincronización de un evento
  def update_players_from_event_sync(event)
    Rails.logger.info "🔄 Actualizando jugadores del evento: #{event.name}"

    players = event.players.includes(:event_seeds)

    results = {
      total: players.count,
      updated: 0,
      failed: 0,
      skipped: 0
    }

    players.find_each do |player|
      begin
        # Siempre actualizar cuando es una sincronización forzada de evento
        if player.update_from_start_gg_api
          results[:updated] += 1
          Rails.logger.info "✅ Actualizado: #{player.entrant_name}"
        else
          results[:failed] += 1
        end

        sleep(@delay_between_requests)

      rescue StandardError => e
        results[:failed] += 1
        Rails.logger.error "❌ Error actualizando #{player.entrant_name}: #{e.message}"
        sleep(@delay_between_requests * 2)
      end
    end

    Rails.logger.info "✅ Actualización del evento completada: #{results[:updated]} actualizados"
    results
  end

  private

  def get_players_to_update
    if @force_update
      # Si es forzado, actualizar todos los jugadores con user_id
      players = Player.where.not(user_id: nil)
      Rails.logger.info "🔍 Modo forzado: encontrados #{players.count} jugadores con user_id"
      players
    else
      # Solo jugadores que necesitan actualización
      players = Player.where("updated_at < ? OR name IS NULL OR country IS NULL", 30.days.ago)
                     .where.not(user_id: nil)
      Rails.logger.info "🔍 Modo normal: encontrados #{players.count} jugadores que necesitan actualización"
      players
    end
  end

  def process_batch(batch)
    results = { updated: 0, failed: 0, skipped: 0 }

    batch.each do |player|
      begin
        if player.user_id.nil?
          results[:skipped] += 1
          Rails.logger.warn "⚠️ Saltando jugador sin user_id: #{player.entrant_name}"
          next
        end

        if player.update_from_start_gg_api
          results[:updated] += 1
          Rails.logger.info "✅ Actualizado: #{player.entrant_name}"
        else
          results[:failed] += 1
          Rails.logger.warn "❌ Falló: #{player.entrant_name}"
        end

        sleep(@delay_between_requests)

      rescue StandardError => e
        results[:failed] += 1
        Rails.logger.error "💥 Error procesando #{player.entrant_name}: #{e.message}"
        sleep(@delay_between_requests * 3) # Pausa más larga en caso de error
      end
    end

    results
  end
end
