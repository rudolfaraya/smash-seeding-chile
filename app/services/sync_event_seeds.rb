require_relative "../../lib/start_gg_queries"
require 'set'

class SyncEventSeeds
  def initialize(event, force: false, update_players: false)
    @event = event
    @client = StartGgClient.new
    @force = force
    @update_players = update_players
    @target_event_id = @event.id
  end

  def call
    Rails.logger.info "🎯 INICIANDO SINCRONIZACIÓN - Evento: #{@event.name} (ID: #{@event.id}) - Torneo: #{@event.tournament.name} (force: #{@force})"
    
    # NUEVA LÓGICA: Si es forzado, eliminar TODOS los seeds y empezar desde cero
    if @force
      existing_count = @event.event_seeds.count
      Rails.logger.info "🧹 SINCRONIZACIÓN FORZADA: Eliminando TODOS los #{existing_count} seeds existentes para evento #{@event.name} (ID: #{@event.id})"
      @event.event_seeds.destroy_all
      Rails.logger.info "✅ Seeds eliminados correctamente para evento #{@event.name}"
    else
      # Si no es forzado y ya hay seeds, no hacer nada
      if @event.event_seeds.any?
        Rails.logger.info "ℹ️ El evento #{@event.name} ya tiene seeds. Saltando sincronización (usar force: true para forzar)"
        return
      end
    end

    Rails.logger.info "🔍 Obteniendo seeds ÚNICAMENTE para evento: #{@event.name} (slug: #{@event.slug})"
    
    begin
      # Obtener seeds con validación estricta
      seeds_data = fetch_seeds_with_strict_validation
      
      if seeds_data.empty?
        Rails.logger.warn "⚠️ No se encontraron seeds para el evento #{@event.name}"
        return
      end

      # NUEVA LÓGICA: Sistema de priorización inteligente para resolver seeds duplicados
      Rails.logger.info "📊 Total seeds obtenidos de la API: #{seeds_data.length}"
      
      # Agrupar seeds por número de seed para detectar duplicados
      seeds_by_number = seeds_data.group_by { |seed| seed[:seed_num] }
      
      # Procesar seeds y resolver conflictos
      resolved_seeds = []
      discarded_players = []
      duplicates_resolved = 0
      
      seeds_by_number.each do |seed_num, competing_seeds|
        if competing_seeds.length == 1
          # No hay conflicto, agregar directamente
          resolved_seeds << competing_seeds.first
        else
          # HAY CONFLICTO: Múltiples jugadores con el mismo seed
          Rails.logger.warn "⚠️ CONFLICTO DE SEED #{seed_num}: #{competing_seeds.length} jugadores compitiendo"
          competing_seeds.each { |s| Rails.logger.warn "   - #{s[:player_name]}" }
          
          # Resolver usando estadísticas históricas
          best_player = resolve_seed_conflict(competing_seeds, seed_num)
          resolved_seeds << best_player
          
          # Guardar los jugadores descartados para reasignar después
          discarded = competing_seeds.reject { |s| s == best_player }
          discarded_players.concat(discarded)
          duplicates_resolved += discarded.length
          
          Rails.logger.info "✅ CONFLICTO RESUELTO: Seed #{seed_num} asignado a #{best_player[:player_name]} (mejor historial)"
          Rails.logger.info "📝 DESCARTADOS: #{discarded.map { |d| d[:player_name] }.join(', ')}"
        end
      end
      
      Rails.logger.info "🎯 RESOLUCIÓN INICIAL: #{resolved_seeds.length} seeds únicos, #{duplicates_resolved} jugadores descartados"
      
      # NUEVA LÓGICA: Encontrar seeds faltantes y reasignar jugadores descartados
      if discarded_players.any?
        Rails.logger.info "🔍 REASIGNANDO #{discarded_players.length} jugadores descartados a seeds faltantes..."
        
        # Encontrar todos los números de seed que deberían existir (1 hasta el máximo)
        used_seeds = resolved_seeds.map { |s| s[:seed_num] }.sort
        max_seed = seeds_data.map { |s| s[:seed_num] }.max
        expected_seeds = (1..max_seed).to_a
        missing_seeds = expected_seeds - used_seeds
        
        Rails.logger.info "📊 Seeds usados: #{used_seeds.length}, Seeds faltantes: #{missing_seeds.length}"
        Rails.logger.info "🔢 Seeds faltantes: #{missing_seeds.first(10).join(', ')}#{missing_seeds.length > 10 ? '...' : ''}"
        
        # Ordenar jugadores descartados por su seed original (menor a mayor)
        discarded_players.sort_by! { |player| player[:seed_num] }
        
        # Asignar seeds faltantes a jugadores descartados
        missing_seeds.each_with_index do |missing_seed, index|
          break if index >= discarded_players.length
          
          player = discarded_players[index]
          original_seed = player[:seed_num]
          player[:seed_num] = missing_seed
          resolved_seeds << player
          
          Rails.logger.info "🔄 REASIGNADO: #{player[:player_name]} (seed original: #{original_seed} → nuevo seed: #{missing_seed})"
        end
        
        # Si aún quedan jugadores descartados, asignarlos a seeds consecutivos después del máximo
        remaining_players = discarded_players[missing_seeds.length..-1] || []
        if remaining_players.any?
          Rails.logger.info "➕ AGREGANDO #{remaining_players.length} jugadores con seeds consecutivos después de #{max_seed}"
          
          remaining_players.each_with_index do |player, index|
            new_seed = max_seed + index + 1
            original_seed = player[:seed_num]
            player[:seed_num] = new_seed
            resolved_seeds << player
            
            Rails.logger.info "➕ AGREGADO: #{player[:player_name]} (seed original: #{original_seed} → nuevo seed: #{new_seed})"
          end
        end
      end
      
      Rails.logger.info "🎯 RESOLUCIÓN COMPLETADA: #{resolved_seeds.length} seeds únicos, #{duplicates_resolved} conflictos resueltos"
      
      # Procesar seeds resueltos
      created_count = 0
      resolved_seeds.each_with_index do |seed_data, index|
        begin
          player = find_or_create_player(seed_data)
          next unless player

          event_seed = @event.event_seeds.build(
            player: player,
            seed_num: seed_data[:seed_num]
          )

          if event_seed.save
            created_count += 1
            Rails.logger.info "  [#{index + 1}/#{resolved_seeds.length}] ✅ Agregado: #{seed_data[:player_name]} (Seed: #{seed_data[:seed_num]})"
          else
            Rails.logger.error "  [#{index + 1}/#{resolved_seeds.length}] ❌ Error al guardar seed para #{seed_data[:player_name]}: #{event_seed.errors.full_messages.join(', ')}"
          end
        rescue => e
          Rails.logger.error "  [#{index + 1}/#{resolved_seeds.length}] ❌ Error procesando #{seed_data[:player_name]}: #{e.message}"
        end
      end

      Rails.logger.info "🎉 SINCRONIZACIÓN COMPLETADA - Evento: #{@event.name}"
      Rails.logger.info "📊 RESUMEN: #{created_count} seeds creados exitosamente de #{resolved_seeds.length} totales"
      Rails.logger.info "🧠 INTELIGENCIA: #{duplicates_resolved} conflictos resueltos usando estadísticas históricas"

    rescue => e
      Rails.logger.error "❌ Error al obtener seeds para evento #{@event.name}: #{e.message}"
      Rails.logger.error "🔍 Backtrace: #{e.backtrace.first(5).join("\n")}"
      raise e
    end
  end

  private

  def fetch_seeds_with_strict_validation
    Rails.logger.info "🔍 FETCH_SEEDS_WITH_STRICT_VALIDATION - Evento ID: #{@event.id}, Nombre: #{@event.name}"
    
    all_seeds = []
    page = 1

    loop do
      Rails.logger.info "📡 Página #{page} - Obteniendo seeds DIRECTAMENTE por ID de evento: #{@event.id}"
      
      variables = { 
        eventId: @event.id,
        perPage: 100,
        page: page 
      }
      
      response = @client.query(StartGgQueries::EVENT_SEEDING_BY_ID_QUERY, variables, "EventSeedingById")
      
      # Validar que la respuesta tenga la estructura esperada
      unless response&.dig('data', 'event')
        Rails.logger.error "❌ Respuesta inválida de la API - no se encontró evento con ID #{@event.id}"
        break
      end
      
      event_data = response['data']['event']
      Rails.logger.info "✅ EVENTO ENCONTRADO DIRECTAMENTE: #{event_data['name']} (ID: #{event_data['id']})"
      
      entrants = event_data.dig('entrants', 'nodes') || []
      Rails.logger.info "👥 Entrants encontrados en página #{page}: #{entrants.length}"
      
      if entrants.empty?
        Rails.logger.info "ℹ️ No hay más entrants en página #{page}"
        break
      end
      
      # Procesar entrants de esta página
      entrants.each do |entrant|
        next unless entrant['initialSeedNum'] && entrant['participants']&.any?
        
        participant = entrant['participants'].first
        next unless participant&.dig('player', 'user')
        
        user_data = participant['player']['user']
        
        seed_data = {
          seed_num: entrant['initialSeedNum'],
          player_name: entrant['name'],
          user_id: user_data['id'],
          player_id: participant['player']['id'],
          user_slug: user_data['slug'],
          name: user_data['name'],
          discriminator: user_data['discriminator'],
          bio: user_data['bio'],
          birthday: user_data['birthday'],
          gender_pronoun: user_data['genderPronoun'],
          city: user_data.dig('location', 'city'),
          state: user_data.dig('location', 'state'),
          country: user_data.dig('location', 'country'),
          twitter: user_data.dig('authorizations')&.first&.dig('externalUsername')
        }
        
        all_seeds << seed_data
      end
      
      # Verificar si hay más páginas
      page_info = event_data.dig('entrants', 'pageInfo')
      total_pages = page_info&.dig('totalPages') || 1
      
      if page >= total_pages
        Rails.logger.info "✅ Procesadas todas las páginas (#{page}/#{total_pages})"
        break
      end
      
      page += 1
    end
    
    Rails.logger.info "📊 Total seeds obtenidos DIRECTAMENTE del evento #{@event.id}: #{all_seeds.length}"
    all_seeds
  end

  def find_or_create_player(seed_data)
    # Buscar jugador existente por user_id (no start_gg_id)
    player = Player.find_by(user_id: seed_data[:user_id])
    
    if player
      # Actualizar datos del jugador si es necesario
      if @update_players
        player.update!(
          name: seed_data[:name],
          discriminator: seed_data[:discriminator],
          bio: seed_data[:bio],
          birthday: seed_data[:birthday],
          city: seed_data[:city],
          state: seed_data[:state],
          country: seed_data[:country],
          twitter_handle: seed_data[:twitter]
        )
        # Manejar gender_pronoun/gender_pronoum
        player.assign_gender_pronoun(seed_data[:gender_pronoun])
        player.save!
      end
      return player
    end
    
    # Crear nuevo jugador
    new_player = Player.new(
      user_id: seed_data[:user_id],
      entrant_name: seed_data[:player_name],
      name: seed_data[:name],
      discriminator: seed_data[:discriminator],
      bio: seed_data[:bio],
      birthday: seed_data[:birthday],
      city: seed_data[:city],
      state: seed_data[:state],
      country: seed_data[:country],
      twitter_handle: seed_data[:twitter]
    )
    
    # Manejar gender_pronoun/gender_pronoum
    new_player.assign_gender_pronoun(seed_data[:gender_pronoun])
    new_player.save!
    new_player
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Error al crear/actualizar jugador #{seed_data[:player_name]}: #{e.message}"
    nil
  end

  # Resuelve conflictos de seeds duplicados usando estadísticas históricas
  def resolve_seed_conflict(competing_seeds, seed_num)
    Rails.logger.info "🧠 Resolviendo conflicto para seed #{seed_num} entre #{competing_seeds.length} jugadores"
    
    best_candidate = nil
    best_score = -1
    
    competing_seeds.each do |seed_data|
      # Buscar jugador en la base de datos
      player = Player.find_by(user_id: seed_data[:user_id])
      
      if player.nil?
        Rails.logger.info "   📊 #{seed_data[:player_name]}: Jugador nuevo (score: 0)"
        score = 0
      else
        # Calcular score basado en historial de seeds
        score = calculate_player_seed_score(player)
        Rails.logger.info "   📊 #{seed_data[:player_name]}: Score histórico: #{score}"
      end
      
      # Actualizar mejor candidato
      if score > best_score
        best_score = score
        best_candidate = seed_data
      end
    end
    
    Rails.logger.info "🏆 Ganador: #{best_candidate[:player_name]} (score: #{best_score})"
    best_candidate
  end
  
  # Calcula un score basado en el historial de seeds del jugador
  def calculate_player_seed_score(player)
    # Obtener todos los seeds históricos del jugador
    historical_seeds = player.event_seeds.includes(:event)
    
    return 0 if historical_seeds.empty?
    
    total_score = 0
    
    historical_seeds.each do |event_seed|
      # Validar que el seed_num no sea nil
      seed_num = event_seed.seed_num
      next if seed_num.nil? || seed_num <= 0
      
      # Score basado en qué tan bajo es el seed (seeds más bajos = mejor jugador)
      # Usamos una fórmula que da más puntos a seeds bajos
      if seed_num <= 8
        # Top 8: puntos muy altos (seed 1 = 200, seed 8 = 125)
        seed_score = 200 - (seed_num - 1) * 10
      elsif seed_num <= 16
        # Top 16: puntos altos (seed 9 = 100, seed 16 = 65)
        seed_score = 100 - (seed_num - 9) * 5
      elsif seed_num <= 32
        # Top 32: puntos medios (seed 17 = 50, seed 32 = 35)
        seed_score = 50 - (seed_num - 17) * 1
      else
        # Resto: puntos bajos pero algo (seed 33+ = 10-1 puntos)
        seed_score = [30 - seed_num, 1].max
      end
      
      # Bonus por participar en eventos (experiencia)
      participation_bonus = 5
      
      # Bonus adicional por seeds muy buenos (top 3)
      champion_bonus = case seed_num
                      when 1 then 100  # Seed 1 = campeón esperado
                      when 2 then 50   # Seed 2 = subcampeón esperado  
                      when 3 then 25   # Seed 3 = top 3
                      else 0
                      end
      
      total_score += seed_score + participation_bonus + champion_bonus
    end
    
    # Score promedio para normalizar por cantidad de participaciones
    valid_seeds_count = historical_seeds.count { |seed| seed.seed_num&.positive? }
    
    if valid_seeds_count == 0
      # Si no hay seeds válidos, solo dar bonus por participación
      experience_bonus = [historical_seeds.count * 3, 50].min
      return experience_bonus
    end
    
    average_score = total_score.to_f / valid_seeds_count
    
    # Bonus por cantidad de participaciones (experiencia)
    experience_bonus = [historical_seeds.count * 3, 50].min
    
    final_score = (average_score + experience_bonus).round(2)
    
    # Mostrar el mejor seed histórico para contexto
    valid_seeds = historical_seeds.select { |seed| seed.seed_num&.positive? }
    best_seed = valid_seeds.map(&:seed_num).min if valid_seeds.any?
    Rails.logger.debug "     Detalles: #{historical_seeds.count} participaciones (#{valid_seeds_count} válidas), mejor seed: #{best_seed || 'N/A'}, score promedio: #{average_score.round(2)}, bonus experiencia: #{experience_bonus}"
    
    final_score
  end
end
