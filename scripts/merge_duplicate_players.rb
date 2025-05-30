#!/usr/bin/env ruby
# Script para mergear jugadores duplicados con diferentes modos de operación
# Ejecutar: ruby scripts/merge_duplicate_players.rb [modo] [argumentos]

# Cargar entorno de Rails
unless defined?(Rails)
  require_relative '../config/environment'
end

class PlayerMerger
  def initialize
    @merged_players = []
    @errors = []
  end

  def merge_players(base_player_id, merge_candidate_id, dry_run: true)
    puts "🔄 #{dry_run ? 'SIMULANDO' : 'EJECUTANDO'} MERGE DE JUGADORES"
    puts "=" * 60
    
    base_player = Player.find(base_player_id)
    merge_candidate = Player.find(merge_candidate_id)
    
    puts "👑 JUGADOR BASE: #{base_player.entrant_name} (ID: #{base_player.id})"
    puts "🔄 JUGADOR A MERGEAR: #{merge_candidate.entrant_name} (ID: #{merge_candidate.id})"
    puts ""
    
    # Validaciones previas
    unless validate_merge(base_player, merge_candidate)
      puts "❌ MERGE CANCELADO: Validaciones fallaron"
      return false
    end
    
    # Mostrar estadísticas antes del merge
    show_pre_merge_stats(base_player, merge_candidate)
    
    if dry_run
      simulate_merge(base_player, merge_candidate)
    else
      execute_merge(base_player, merge_candidate)
    end
  end

  def batch_merge_from_csv(csv_file, confidence_threshold: 0.8, dry_run: true)
    puts "📄 PROCESANDO MERGES DESDE CSV: #{csv_file}"
    puts "🎯 Umbral de confianza: #{(confidence_threshold * 100).to_i}%"
    puts "#{dry_run ? '🧪 MODO SIMULACIÓN' : '⚡ MODO EJECUCIÓN'}"
    puts "=" * 60
    
    require 'csv'
    
    merges_to_process = []
    
    CSV.foreach(csv_file, headers: true) do |row|
      confidence = row['Confidence %'].to_f / 100.0
      next if confidence < confidence_threshold
      
      merges_to_process << {
        base_id: row['Base Player ID'].to_i,
        merge_id: row['Merge Candidate ID'].to_i,
        base_name: row['Base Player Name'],
        merge_name: row['Merge Candidate Name'],
        confidence: confidence
      }
    end
    
    puts "📊 Merges a procesar: #{merges_to_process.size}"
    puts ""
    
    merges_to_process.each_with_index do |merge_data, index|
      puts "\n#{index + 1}/#{merges_to_process.size} - Procesando: #{merge_data[:merge_name]} → #{merge_data[:base_name]} (#{(merge_data[:confidence] * 100).round(1)}%)"
      
      begin
        merge_players(merge_data[:base_id], merge_data[:merge_id], dry_run: dry_run)
      rescue => e
        puts "❌ Error en merge: #{e.message}"
        @errors << {
          base_id: merge_data[:base_id],
          merge_id: merge_data[:merge_id],
          error: e.message
        }
      end
      
      puts "\n" + "-" * 40
    end
    
    generate_batch_summary
  end

  def interactive_review_from_csv(csv_file, confidence_threshold: 0.7)
    puts "📄 REVISIÓN INTERACTIVA DESDE CSV: #{csv_file}"
    puts "🎯 Umbral mínimo de confianza: #{(confidence_threshold * 100).to_i}%"
    puts "=" * 60
    
    require 'csv'
    
    # Cargar y agrupar candidatos por grupo
    groups = {}
    
    CSV.foreach(csv_file, headers: true) do |row|
      confidence = row['Confidence %'].to_f / 100.0
      next if confidence < confidence_threshold
      
      group_number = row['Grupo'].to_i
      groups[group_number] ||= []
      groups[group_number] << {
        base_id: row['Base Player ID'].to_i,
        merge_id: row['Merge Candidate ID'].to_i,
        base_name: row['Base Player Name'],
        merge_name: row['Merge Candidate Name'],
        confidence: confidence,
        base_events: row['Base Player Events'].to_i,
        merge_events: row['Merge Candidate Events'].to_i
      }
    end
    
    puts "📊 Grupos encontrados: #{groups.size}"
    puts "📋 Total candidatos: #{groups.values.flatten.size}"
    puts ""
    
    processed_merges = []
    skipped_merges = []
    
    groups.each do |group_number, candidates|
      puts "\n" + "="*80
      puts "🔍 GRUPO #{group_number}: #{candidates.size} candidato(s) para merge"
      puts "="*80
      
      # Mostrar información del jugador base (debería ser el mismo para todo el grupo)
      base_candidate = candidates.first
      base_player = Player.find(base_candidate[:base_id])
      
      puts "\n👑 JUGADOR BASE:"
      display_detailed_player_info(base_player, "  ")
      
      decision = nil # Inicializar la variable aquí
      
      candidates.each_with_index do |candidate, index|
        puts "\n" + "-"*60
        puts "🔄 CANDIDATO #{index + 1}/#{candidates.size} PARA MERGE:"
        puts "-"*60
        
        merge_player = Player.find(candidate[:merge_id])
        display_detailed_player_info(merge_player, "  ")
        
        puts "\n📊 ANÁLISIS DEL MERGE:"
        puts "  🎯 Confianza: #{(candidate[:confidence] * 100).round(1)}%"
        puts "  📈 Eventos base: #{candidate[:base_events]}"
        puts "  📉 Eventos candidato: #{candidate[:merge_events]}"
        
        # Mostrar similitudes y diferencias
        show_merge_comparison(base_player, merge_player)
        
        # Preguntar qué hacer
        decision = ask_merge_decision(base_player, merge_player)
        
        case decision
        when 'merge'
          puts "\n⚡ Ejecutando merge..."
          begin
            merge_players(base_candidate[:base_id], candidate[:merge_id], dry_run: false)
            processed_merges << candidate
            puts "✅ Merge completado exitosamente"
            
            # Recargar el jugador base para mostrar estadísticas actualizadas
            base_player.reload
          rescue => e
            puts "❌ Error en merge: #{e.message}"
            skipped_merges << candidate.merge(error: e.message)
          end
          
        when 'simulate'
          puts "\n🧪 Simulando merge..."
          merge_players(base_candidate[:base_id], candidate[:merge_id], dry_run: true)
          
          puts "\n¿Proceder con el merge real? (y/N): "
          if STDIN.gets.chomp.downcase == 'y'
            begin
              merge_players(base_candidate[:base_id], candidate[:merge_id], dry_run: false)
              processed_merges << candidate
              puts "✅ Merge real completado"
              base_player.reload
            rescue => e
              puts "❌ Error en merge real: #{e.message}"
              skipped_merges << candidate.merge(error: e.message)
            end
          else
            skipped_merges << candidate.merge(reason: 'Usuario canceló después de simulación')
          end
          
        when 'skip'
          puts "⏭️  Saltando este merge"
          skipped_merges << candidate.merge(reason: 'Usuario saltó')
          
        when 'stop'
          puts "🛑 Deteniendo revisión interactiva"
          break
        end
        
        puts "\n" + "~"*40
        
        # Si el usuario eligió stop, salir del loop de candidatos
        break if decision == 'stop'
      end
      
      # Si el usuario eligió stop, salir del loop de grupos
      break if decision == 'stop'
    end
    
    generate_interactive_summary(processed_merges, skipped_merges)
  end

  def display_detailed_player_info(player, indent = "")
    events_count = player.events_count
    tournaments_count = player.tournaments_count
    recent_tournament = player.recent_tournament
    has_account = player.user_id.present?
    has_team = player.primary_team_optimized.present?
    team_name = has_team ? player.primary_team_optimized.name : "Sin equipo"
    
    puts "#{indent}📊 #{player.entrant_name} (ID: #{player.id})"
    puts "#{indent}   📈 Actividad:"
    puts "#{indent}      • Eventos: #{events_count}"
    puts "#{indent}      • Torneos únicos: #{tournaments_count}"
    puts "#{indent}      • Último torneo: #{recent_tournament&.name || 'Ninguno'}"
    if recent_tournament
      puts "#{indent}      • Fecha último: #{recent_tournament.start_at&.strftime('%d/%m/%Y') || 'N/A'}"
    end
    
    puts "#{indent}   👤 Información:"
    puts "#{indent}      • Cuenta start.gg: #{has_account ? '✅ Sí' : '❌ No'}"
    if has_account
      puts "#{indent}      • User ID: #{player.user_id}"
      if player.user.present?
        puts "#{indent}      • Usuario: #{player.user.display_name} (#{player.user.email})"
      else
        puts "#{indent}      • Usuario: ⚠️ User ID presente pero usuario no encontrado"
      end
    else
      puts "#{indent}      • Start.gg ID: #{player.start_gg_id}"
    end
    puts "#{indent}      • Equipo: #{team_name}"
    puts "#{indent}      • País: #{player.country.presence || 'No especificado'}"
    puts "#{indent}      • Ciudad: #{player.city.presence || 'No especificada'}"
    puts "#{indent}      • Twitter: #{player.twitter_handle.present? ? "@#{player.twitter_handle}" : 'No especificado'}"
    
    # Mostrar personajes si los tiene
    characters = []
    characters << player.character_1 if player.character_1.present?
    characters << player.character_2 if player.character_2.present?
    characters << player.character_3 if player.character_3.present?
    
    if characters.any?
      char_names = characters.map { |c| Player::SMASH_CHARACTERS[c] || c }.join(', ')
      puts "#{indent}      • Personajes: #{char_names}"
    end
  end

  def show_merge_comparison(base_player, merge_player)
    puts "  🔍 COMPARACIÓN:"
    
    # Comparar información básica
    compare_field("País", base_player.country, merge_player.country)
    compare_field("Ciudad", base_player.city, merge_player.city)
    compare_field("Twitter", base_player.twitter_handle, merge_player.twitter_handle)
    compare_field("Equipo principal", 
                  base_player.primary_team_optimized&.name, 
                  merge_player.primary_team_optimized&.name)
    
    # Comparar eventos en común
    common_events = base_player.events & merge_player.events
    if common_events.any?
      puts "  ⚠️  EVENTOS EN COMÚN: #{common_events.size}"
      puts "     (Esto podría indicar que NO son la misma persona)"
      common_events.first(3).each do |event|
        puts "     • #{event.tournament.name} - #{event.name}"
      end
      puts "     • ..." if common_events.size > 3
      
      # Si tienen muchos eventos en común, es una señal MUY fuerte de que son diferentes personas
      if common_events.size >= 5
        puts "  🚨 ALERTA: #{common_events.size} eventos en común es MUCHO!"
        puts "     Esto sugiere fuertemente que son PERSONAS DIFERENTES"
        puts "     que compitieron en los mismos torneos al mismo tiempo."
      end
    else
      puts "  ✅ Sin eventos en común (buena señal para merge)"
    end
    
    # Mostrar fechas de actividad
    base_first = base_player.events.joins(:tournament).minimum('tournaments.start_at')
    merge_first = merge_player.events.joins(:tournament).minimum('tournaments.start_at')
    base_last = base_player.events.joins(:tournament).maximum('tournaments.start_at')
    merge_last = merge_player.events.joins(:tournament).maximum('tournaments.start_at')
    
    puts "  📅 PERÍODOS DE ACTIVIDAD:"
    puts "     Base: #{base_first&.strftime('%m/%Y') || 'N/A'} - #{base_last&.strftime('%m/%Y') || 'N/A'}"
    puts "     Candidato: #{merge_first&.strftime('%m/%Y') || 'N/A'} - #{merge_last&.strftime('%m/%Y') || 'N/A'}"
    
    # Analizar solapamiento temporal
    if base_first && base_last && merge_first && merge_last
      # Verificar si los períodos se solapan
      overlap_start = [base_first, merge_first].max
      overlap_end = [base_last, merge_last].min
      
      if overlap_start <= overlap_end
        overlap_months = ((overlap_end.year - overlap_start.year) * 12 + (overlap_end.month - overlap_start.month))
        if overlap_months > 6 && common_events.size > 2
          puts "  ⚠️  SOLAPAMIENTO TEMPORAL: #{overlap_months} meses + eventos en común"
          puts "     Esto refuerza que probablemente son personas diferentes"
        end
      end
    end
  end

  def compare_field(field_name, base_value, merge_value)
    base_str = base_value.present? ? base_value.to_s : "No especificado"
    merge_str = merge_value.present? ? merge_value.to_s : "No especificado"
    
    if base_value.present? && merge_value.present?
      if base_value.to_s.downcase == merge_value.to_s.downcase
        puts "     ✅ #{field_name}: #{base_str} (coincide)"
      else
        puts "     ⚠️  #{field_name}: Base='#{base_str}' vs Candidato='#{merge_str}'"
      end
    elsif base_value.present?
      puts "     ℹ️  #{field_name}: Base='#{base_str}', Candidato=vacío"
    elsif merge_value.present?
      puts "     ➕ #{field_name}: Base=vacío, se añadiría '#{merge_str}'"
    else
      puts "     ➖ #{field_name}: Ambos vacíos"
    end
  end

  def ask_merge_decision(base_player, merge_player)
    loop do
      puts "\n❓ ¿Qué quieres hacer?"
      puts "  [m]erge   - Realizar merge inmediatamente"
      puts "  [s]imular - Ver simulación antes de decidir"
      puts "  [k]ip     - Saltar este candidato"
      puts "  [q]uit    - Detener revisión"
      puts "  [h]elp    - Mostrar ayuda"
      print "\nTu decisión (m/s/k/q/h): "
      
      choice = STDIN.gets.chomp.downcase
      
      case choice
      when 'm', 'merge'
        return 'merge'
      when 's', 'sim', 'simulate'
        return 'simulate'
      when 'k', 'skip'
        return 'skip'
      when 'q', 'quit', 'stop'
        return 'stop'
      when 'h', 'help'
        show_decision_help
      else
        puts "❌ Opción inválida. Usa m/s/k/q/h"
      end
    end
  end

  def show_decision_help
    puts "\n📖 AYUDA PARA DECISIONES:"
    puts "="*50
    puts "🟢 MERGE si:"
    puts "   • Los nombres son claramente la misma persona"
    puts "   • No hay eventos en común (o muy pocos)"
    puts "   • La información personal coincide o se complementa"
    puts "   • Los períodos de actividad no se superponen mucho"
    puts ""
    puts "🟡 SIMULAR si:"
    puts "   • Tienes dudas pero parece probable"
    puts "   • Quieres ver exactamente qué se transferiría"
    puts "   • El nombre es similar pero no estás 100% seguro"
    puts ""
    puts "🔴 SALTAR si:"
    puts "   • Los nombres son diferentes personas"
    puts "   • Hay muchos eventos en común"
    puts "   • La información personal es contradictoria"
    puts "   • Tienes cualquier duda sobre si son la misma persona"
    puts ""
    puts "📊 INDICADORES IMPORTANTES:"
    puts "   • ⚠️  Eventos en común = MAL (probablemente personas diferentes)"
    puts "   • ✅ Sin eventos en común = BIEN"
    puts "   • ⚠️  Información contradictoria = REVISAR"
    puts "   • ✅ Información coincidente/complementaria = BIEN"
  end

  def generate_interactive_summary(processed_merges, skipped_merges)
    puts "\n" + "="*60
    puts "📋 RESUMEN DE REVISIÓN INTERACTIVA"
    puts "="*60
    puts "✅ Merges realizados: #{processed_merges.size}"
    puts "⏭️  Candidatos saltados: #{skipped_merges.size}"
    
    if processed_merges.any?
      total_events_merged = processed_merges.sum { |m| m[:merge_events] }
      puts "📊 Total eventos transferidos: #{total_events_merged}"
      
      puts "\n🎉 MERGES COMPLETADOS:"
      processed_merges.each do |merge|
        puts "  ✅ #{merge[:merge_name]} → #{merge[:base_name]} (#{merge[:merge_events]} eventos)"
      end
    end
    
    if skipped_merges.any?
      puts "\n⏭️  CANDIDATOS SALTADOS:"
      skipped_merges.each do |skip|
        reason = skip[:reason] || skip[:error] || "Motivo no especificado"
        puts "  ⏭️  #{skip[:merge_name]} → #{skip[:base_name]} (#{reason})"
      end
    end
    
    puts "\n💡 CONSEJO: Puedes volver a ejecutar el análisis para buscar nuevos duplicados"
    puts "   después de los merges realizados."
  end

  private

  def validate_merge(base_player, merge_candidate)
    validations = []
    
    # Validación 1: No pueden ser el mismo jugador
    if base_player.id == merge_candidate.id
      validations << "❌ No se puede mergear un jugador consigo mismo"
    else
      validations << "✅ IDs diferentes"
    end
    
    # Validación 2: Si ambos tienen cuenta de usuario, revisar cuidadosamente
    if base_player.user_id.present? && merge_candidate.user_id.present?
      validations << "⚠️  AMBOS TIENEN CUENTA DE USUARIO - Revisar manualmente"
      if base_player.user.present? && merge_candidate.user.present?
        puts "   Base user: #{base_player.user.display_name} (#{base_player.user.email})"
        puts "   Merge user: #{merge_candidate.user.display_name} (#{merge_candidate.user.email})"
      else
        puts "   ⚠️ Uno o ambos usuarios no encontrados en la base de datos"
        puts "   Base user ID: #{base_player.user_id} (exists: #{base_player.user.present?})"
        puts "   Merge user ID: #{merge_candidate.user_id} (exists: #{merge_candidate.user.present?})"
      end
    else
      validations << "✅ Solo uno o ninguno tiene cuenta de usuario"
    end
    
    # Validación 3: Verificar que el candidato a merge tenga menos o igual actividad
    if merge_candidate.events_count > base_player.events_count
      validations << "⚠️  CANDIDATO TIENE MÁS EVENTOS - Considera intercambiar roles"
    else
      validations << "✅ Candidato tiene menos o igual actividad"
    end
    
    puts "🔍 VALIDACIONES:"
    validations.each { |v| puts "  #{v}" }
    puts ""
    
    # Retornar false solo si hay errores críticos
    !validations.any? { |v| v.include?('❌') }
  end

  def show_pre_merge_stats(base_player, merge_candidate)
    puts "📊 ESTADÍSTICAS PRE-MERGE:"
    puts "-" * 30
    
    puts "Base player (#{base_player.entrant_name}):"
    puts "  • Eventos: #{base_player.events_count}"
    puts "  • Torneos: #{base_player.tournaments_count}"
    puts "  • Equipos: #{base_player.teams.count}"
    puts "  • Usuario: #{base_player.user&.display_name || 'Sin cuenta'}"
    
    puts "\nMerge candidate (#{merge_candidate.entrant_name}):"
    puts "  • Eventos: #{merge_candidate.events_count}"
    puts "  • Torneos: #{merge_candidate.tournaments_count}"
    puts "  • Equipos: #{merge_candidate.teams.count}"
    puts "  • Usuario: #{merge_candidate.user&.display_name || 'Sin cuenta'}"
    puts ""
  end

  def simulate_merge(base_player, merge_candidate)
    puts "🧪 SIMULANDO MERGE..."
    puts "-" * 20
    
    # Simular transferencia de event_seeds
    seeds_to_transfer = merge_candidate.event_seeds.count
    puts "📊 Se transferirían #{seeds_to_transfer} event_seeds"
    
    if seeds_to_transfer > 0
      puts "   Eventos únicos a transferir:"
      merge_candidate.events.includes(:tournament).each do |event|
        puts "   • #{event.tournament.name} - #{event.name}"
      end
    end
    
    # Simular transferencia de equipos
    teams_to_transfer = merge_candidate.player_teams.count
    puts "👥 Se transferirían #{teams_to_transfer} relaciones de equipo"
    
    if teams_to_transfer > 0
      merge_candidate.player_teams.includes(:team).each do |pt|
        puts "   • #{pt.team.name} #{pt.is_primary? ? '(Principal)' : '(Secundario)'}"
      end
    end
    
    # Simular actualización de información faltante
    puts "📝 Información a sincronizar:"
    sync_info = calculate_info_sync(base_player, merge_candidate)
    sync_info.each { |info| puts "   #{info}" }
    
    # Mostrar estadísticas finales simuladas
    puts "\n📈 ESTADÍSTICAS FINALES (simuladas):"
    final_events = base_player.events_count + merge_candidate.events_count
    final_tournaments = (base_player.events.map(&:tournament) + merge_candidate.events.map(&:tournament)).uniq.count
    puts "  • Total eventos: #{final_events}"
    puts "  • Total torneos únicos: #{final_tournaments}"
    
    puts "\n✅ SIMULACIÓN COMPLETADA"
  end

  def execute_merge(base_player, merge_candidate)
    puts "⚡ EJECUTANDO MERGE..."
    puts "-" * 20
    
    ActiveRecord::Base.transaction do
      # 1. Transferir todos los event_seeds
      transferred_seeds = transfer_event_seeds(base_player, merge_candidate)
      puts "✅ Transferidos #{transferred_seeds} event_seeds"
      
      # 2. Transferir información de equipos
      transferred_teams = transfer_team_associations(base_player, merge_candidate)
      puts "✅ Procesadas #{transferred_teams} relaciones de equipo"
      
      # 3. Sincronizar información del perfil
      sync_profile_info(base_player, merge_candidate)
      puts "✅ Información del perfil sincronizada"
      
      # 4. Manejar relación con usuario si existe
      handle_user_association(base_player, merge_candidate)
      
      # 5. Invalidar cache de players
      PlayersFilterService.invalidate_cache
      puts "✅ Cache invalidado"
      
      # 6. Eliminar el jugador mergeado
      merge_candidate_name = merge_candidate.entrant_name
      merge_candidate_id = merge_candidate.id
      merge_candidate.destroy!
      puts "✅ Jugador #{merge_candidate_name} (ID: #{merge_candidate_id}) eliminado"
      
      @merged_players << {
        base_player: base_player,
        merged_player_name: merge_candidate_name,
        merged_player_id: merge_candidate_id,
        transferred_seeds: transferred_seeds,
        transferred_teams: transferred_teams
      }
      
      puts "\n🎉 MERGE COMPLETADO EXITOSAMENTE"
      show_post_merge_stats(base_player)
    end
  rescue => e
    puts "❌ ERROR EN MERGE: #{e.message}"
    puts "🔄 Transacción revertida"
    raise e
  end

  def transfer_event_seeds(base_player, merge_candidate)
    transferred = 0
    
    merge_candidate.event_seeds.find_each do |seed|
      # Verificar si ya existe un seed para este jugador en este evento
      existing_seed = base_player.event_seeds.find_by(event: seed.event)
      
      if existing_seed
        # Si ya existe, mantener el mejor seed (más bajo)
        if seed.seed_num.present? && existing_seed.seed_num.present?
          if seed.seed_num < existing_seed.seed_num
            existing_seed.update!(seed_num: seed.seed_num)
            puts "   📊 Actualizado seed #{existing_seed.event.name}: #{existing_seed.seed_num} → #{seed.seed_num}"
          end
        elsif seed.seed_num.present? && existing_seed.seed_num.nil?
          existing_seed.update!(seed_num: seed.seed_num)
        end
        
        # Eliminar el seed duplicado
        seed.destroy!
      else
        # Transferir el seed al jugador base
        seed.update!(player: base_player)
        transferred += 1
      end
    end
    
    transferred
  end

  def transfer_team_associations(base_player, merge_candidate)
    transferred = 0
    
    merge_candidate.player_teams.find_each do |pt|
      # Verificar si el jugador base ya está en este equipo
      existing_pt = base_player.player_teams.find_by(team: pt.team)
      
      if existing_pt
        # Si ya está en el equipo, mantener la relación principal si la tiene el candidato
        if pt.is_primary? && !existing_pt.is_primary?
          existing_pt.update!(is_primary: true)
          puts "   👥 Equipo #{pt.team.name} marcado como principal"
        end
        
        # Eliminar la relación duplicada
        pt.destroy!
      else
        # Transferir la relación al jugador base
        pt.update!(player: base_player)
        transferred += 1
        puts "   👥 Transferido equipo: #{pt.team.name} #{pt.is_primary? ? '(Principal)' : ''}"
      end
    end
    
    transferred
  end

  def sync_profile_info(base_player, merge_candidate)
    updates = {}
    
    # Sincronizar información faltante del candidato al base
    if base_player.name.blank? && merge_candidate.name.present?
      updates[:name] = merge_candidate.name
    end
    
    if base_player.country.blank? && merge_candidate.country.present?
      updates[:country] = merge_candidate.country
    end
    
    if base_player.city.blank? && merge_candidate.city.present?
      updates[:city] = merge_candidate.city
    end
    
    if base_player.state.blank? && merge_candidate.state.present?
      updates[:state] = merge_candidate.state
    end
    
    if base_player.twitter_handle.blank? && merge_candidate.twitter_handle.present?
      updates[:twitter_handle] = merge_candidate.twitter_handle
    end
    
    if base_player.bio.blank? && merge_candidate.bio.present?
      updates[:bio] = merge_candidate.bio
    end
    
    # Sincronizar personajes si el base no los tiene
    if base_player.character_1.blank? && merge_candidate.character_1.present?
      updates[:character_1] = merge_candidate.character_1
      updates[:skin_1] = merge_candidate.skin_1
    end
    
    if base_player.character_2.blank? && merge_candidate.character_2.present?
      updates[:character_2] = merge_candidate.character_2
      updates[:skin_2] = merge_candidate.skin_2
    end
    
    if base_player.character_3.blank? && merge_candidate.character_3.present?
      updates[:character_3] = merge_candidate.character_3
      updates[:skin_3] = merge_candidate.skin_3
    end
    
    if updates.any?
      base_player.update!(updates)
      puts "   📝 Actualizada información: #{updates.keys.join(', ')}"
    end
  end

  def handle_user_association(base_player, merge_candidate)
    # Si el base no tiene usuario pero el candidato sí, transferir la asociación
    if base_player.user_id.nil? && merge_candidate.user_id.present?
      user = merge_candidate.user
      if user.present?
        merge_candidate.update!(user_id: nil)
        base_player.update!(user_id: user.id)
        puts "   👤 Usuario #{user.display_name} transferido al jugador base"
      else
        puts "   ⚠️ User ID presente en candidato pero usuario no encontrado en BD"
      end
    elsif merge_candidate.user_id.present?
      # Si ambos tienen usuario, notificar para revisión manual
      puts "   ⚠️  Ambos jugadores tienen usuario - Revisar asociaciones manualmente"
    end
  end

  def calculate_info_sync(base_player, merge_candidate)
    sync_info = []
    
    sync_info << "📝 Nombre: #{merge_candidate.name}" if base_player.name.blank? && merge_candidate.name.present?
    sync_info << "🌍 País: #{merge_candidate.country}" if base_player.country.blank? && merge_candidate.country.present?
    sync_info << "🏙️  Ciudad: #{merge_candidate.city}" if base_player.city.blank? && merge_candidate.city.present?
    sync_info << "🐦 Twitter: #{merge_candidate.twitter_handle}" if base_player.twitter_handle.blank? && merge_candidate.twitter_handle.present?
    
    # Manejar usuario de forma segura
    if base_player.user_id.nil? && merge_candidate.user_id.present?
      if merge_candidate.user.present?
        sync_info << "👤 Usuario: #{merge_candidate.user.display_name}"
      else
        sync_info << "👤 Usuario: ⚠️ User ID presente pero usuario no encontrado"
      end
    end
    
    # Personajes
    if base_player.character_1.blank? && merge_candidate.character_1.present?
      char_name = Player::SMASH_CHARACTERS[merge_candidate.character_1] || merge_candidate.character_1
      sync_info << "🎮 Personaje 1: #{char_name}"
    end
    
    sync_info << "ℹ️  Sin información nueva para sincronizar" if sync_info.empty?
    
    sync_info
  end

  def show_post_merge_stats(base_player)
    # Recargar las estadísticas
    base_player.reload
    
    puts "\n📈 ESTADÍSTICAS POST-MERGE:"
    puts "-" * 25
    puts "👑 #{base_player.entrant_name} (ID: #{base_player.id})"
    puts "  • Eventos totales: #{base_player.events_count}"
    puts "  • Torneos únicos: #{base_player.tournaments_count}"
    puts "  • Equipos: #{base_player.teams.count}"
    puts "  • Último torneo: #{base_player.recent_tournament&.name || 'Ninguno'}"
  end

  def generate_batch_summary
    puts "\n📋 RESUMEN DEL BATCH MERGE"
    puts "=" * 40
    puts "✅ Merges exitosos: #{@merged_players.size}"
    puts "❌ Errores: #{@errors.size}"
    
    if @merged_players.any?
      total_events_transferred = @merged_players.sum { |m| m[:transferred_seeds] }
      puts "📊 Total eventos transferidos: #{total_events_transferred}"
      
      puts "\n🎉 MERGES COMPLETADOS:"
      @merged_players.each do |merge|
        puts "  • #{merge[:merged_player_name]} → #{merge[:base_player].entrant_name} (#{merge[:transferred_seeds]} eventos)"
      end
    end
    
    if @errors.any?
      puts "\n❌ ERRORES:"
      @errors.each do |error|
        puts "  • IDs #{error[:merge_id]} → #{error[:base_id]}: #{error[:error]}"
      end
    end
  end
end

# Función de ayuda para uso desde consola
def merge_players_interactive
  puts "🔄 MERGE INTERACTIVO DE JUGADORES"
  puts "=" * 40
  
  print "ID del jugador base (destino): "
  base_id = STDIN.gets.chomp.to_i
  
  print "ID del jugador a mergear (origen): "
  merge_id = STDIN.gets.chomp.to_i
  
  print "¿Ejecutar merge real? (y/N): "
  execute = STDIN.gets.chomp.downcase == 'y'
  
  merger = PlayerMerger.new
  merger.merge_players(base_id, merge_id, dry_run: !execute)
end

# Ejecutar si es llamado directamente
if __FILE__ == $0
  puts "🔄 SCRIPT DE MERGE DE JUGADORES DUPLICADOS"
  puts "=" * 50
  puts "Uso del script:"
  puts "1. Revisión interactiva: ruby merge_duplicate_players.rb interactive archivo.csv [confianza]"
  puts "2. Merge específico: ruby merge_duplicate_players.rb merge base_id merge_id [ejecutar]"
  puts "3. Merge masivo: ruby merge_duplicate_players.rb batch archivo.csv [confianza] [ejecutar]"
  puts "4. Merge manual: ruby merge_duplicate_players.rb manual"
  puts ""
  
  case ARGV[0]
  when 'interactive'
    csv_file = ARGV[1]
    confidence = (ARGV[2] || '0.7').to_f
    
    if csv_file && File.exist?(csv_file)
      merger = PlayerMerger.new
      merger.interactive_review_from_csv(csv_file, confidence_threshold: confidence)
    else
      puts "❌ Archivo CSV no encontrado: #{csv_file}"
      puts "\n💡 Primero ejecuta: ruby analyze_duplicate_players.rb"
      puts "   para generar el archivo CSV con los duplicados encontrados."
    end
    
  when 'merge'
    base_id = ARGV[1].to_i
    merge_id = ARGV[2].to_i
    execute = ARGV[3] == 'ejecutar'
    
    if base_id > 0 && merge_id > 0
      merger = PlayerMerger.new
      merger.merge_players(base_id, merge_id, dry_run: !execute)
    else
      puts "❌ IDs inválidos"
    end
    
  when 'batch'
    csv_file = ARGV[1]
    confidence = (ARGV[2] || '0.8').to_f
    execute = ARGV[3] == 'ejecutar'
    
    if csv_file && File.exist?(csv_file)
      merger = PlayerMerger.new
      merger.batch_merge_from_csv(csv_file, confidence_threshold: confidence, dry_run: !execute)
    else
      puts "❌ Archivo CSV no encontrado: #{csv_file}"
    end
    
  when 'manual'
    merge_players_interactive
    
  else
    puts "📖 DESCRIPCIÓN DE MODOS:"
    puts ""
    puts "🎯 INTERACTIVE (RECOMENDADO):"
    puts "   Revisa cada candidato individualmente y decide qué hacer."
    puts "   Muestra información detallada y permite comparar jugadores."
    puts "   Ejemplo: ruby merge_duplicate_players.rb interactive duplicados.csv 0.7"
    puts ""
    puts "⚡ MERGE:"
    puts "   Merge directo entre dos jugadores específicos."
    puts "   Ejemplo: ruby merge_duplicate_players.rb merge 12345 67890 ejecutar"
    puts ""
    puts "🔄 BATCH:"
    puts "   Merge automático de todos los candidatos que superen el umbral."
    puts "   Ejemplo: ruby merge_duplicate_players.rb batch duplicados.csv 0.8 ejecutar"
    puts ""
    puts "👤 MANUAL:"
    puts "   Merge interactivo pidiendo IDs manualmente."
    puts "   Ejemplo: ruby merge_duplicate_players.rb manual"
    puts ""
    puts "🚀 FLUJO RECOMENDADO:"
    puts "1. ruby analyze_duplicate_players.rb"
    puts "2. ruby merge_duplicate_players.rb interactive archivo_generado.csv"
    puts ""
    puts "💡 CONSEJOS:"
    puts "   • Usa 'interactive' para máximo control"
    puts "   • Empieza con confianza 0.7 para revisar más casos"
    puts "   • El modo 'batch' es para casos muy seguros (≥0.8)"
  end
end 