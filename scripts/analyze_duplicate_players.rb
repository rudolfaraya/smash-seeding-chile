#!/usr/bin/env ruby
# Script para analizar jugadores duplicados con nombres similares

# Cargar entorno de Rails
unless defined?(Rails)
  require_relative '../config/environment'
end

require 'csv'
require 'set'

class DuplicatePlayersAnalyzer
  SIMILARITY_THRESHOLD = 0.8
  MIN_ACTIVITY_THRESHOLD = 2 # Mínimo de eventos para considerar actividad significativa

  def initialize
    @potential_duplicates = []
  end

  def analyze
    puts "🔍 ANALIZANDO JUGADORES DUPLICADOS"
    puts "=" * 50

    puts "📊 Información general:"
    puts "- Total de jugadores: #{Player.count}"
    puts "- Jugadores con actividad: #{Player.joins(:event_seeds).distinct.count}"
    puts "- Umbral de similitud: #{(SIMILARITY_THRESHOLD * 100).to_i}%"
    puts "- Mínimo de eventos para considerar: #{MIN_ACTIVITY_THRESHOLD}"
    puts ""

    puts "⏳ Cargando jugadores y sus relaciones..."
    # Obtener todos los jugadores con sus estadísticas básicas
    players = Player.includes(:event_seeds, :user, player_teams: :team)
    puts "✅ #{players.size} jugadores cargados"

    puts "\n🔍 Iniciando búsqueda de grupos similares..."
    # Agrupar por nombres similares
    groups = find_similar_name_groups(players)

    puts "\n🎯 GRUPOS DE NOMBRES SIMILARES ENCONTRADOS: #{groups.size}"
    puts "-" * 40

    if groups.empty?
      puts "✅ No se encontraron grupos de nombres similares."
      return
    end

    groups.each_with_index do |group, index|
      analyze_group(group, index + 1)
    end

    generate_summary
    generate_csv_report if @potential_duplicates.any?
  end

  private

  def find_similar_name_groups(players)
    groups = []
    processed_players = Set.new
    total_players = players.size

    puts "📝 Analizando #{total_players} jugadores..."

    # Optimización: agrupar por primeras letras para reducir comparaciones
    players_by_initial = players.group_by { |p| normalize_name(p.entrant_name)[0, 2].downcase }

    puts "🔤 Jugadores agrupados por iniciales: #{players_by_initial.keys.size} grupos"

    current_player = 0

    players.each_with_index do |player, index|
      current_player = index + 1

      # Mostrar progreso cada 100 jugadores
      if current_player % 100 == 0 || current_player == total_players
        progress = (current_player.to_f / total_players * 100).round(1)
        puts "⏳ Progreso: #{current_player}/#{total_players} (#{progress}%) - Grupos encontrados: #{groups.size}"
      end

      next if processed_players.include?(player.id)

      similar_players = find_similar_players_optimized(player, players_by_initial, processed_players)

      if similar_players.size > 1
        groups << similar_players
        similar_players.each { |p| processed_players.add(p.id) }
        puts "🎯 Grupo #{groups.size} encontrado: #{similar_players.map(&:entrant_name).join(', ')}"
      else
        processed_players.add(player.id)
      end
    end

    puts "✅ Análisis completado. Ordenando grupos por actividad..."
    groups.sort_by { |group| -group.map(&:events_count).sum }
  end

  def find_similar_players_optimized(target_player, players_by_initial, processed_players)
    target_normalized = normalize_name(target_player.entrant_name)
    target_initial = target_normalized[0, 2].downcase
    similar = [ target_player ]

    # Solo comparar con jugadores que tienen iniciales similares
    candidates = []

    # Buscar en el mismo grupo de iniciales
    candidates.concat(players_by_initial[target_initial] || [])

    # Buscar en grupos de iniciales similares (diferencia de 1 carácter)
    players_by_initial.keys.each do |initial|
      if initial != target_initial && levenshtein_distance(target_initial, initial) <= 1
        candidates.concat(players_by_initial[initial] || [])
      end
    end

    candidates.each do |player|
      next if player.id == target_player.id
      next if processed_players.include?(player.id)

      player_normalized = normalize_name(player.entrant_name)

      # Calcular similitud usando diferentes métricas
      if names_are_similar?(target_normalized, player_normalized, target_player.entrant_name, player.entrant_name)
        similar << player
      end
    end

    similar
  end

  def normalize_name(name)
    return "" if name.blank?

    # Remover prefijos de equipo/región comunes
    normalized = name.downcase
    normalized = normalized.gsub(/^(sf|cl|scl|vlp|anf|tmc|iqq|nbl|family|smash|family)\s*[\|\-\s]+/i, '')
    normalized = normalized.gsub(/[\|\-\s]*\s*(sf|cl|scl|vlp|anf|tmc|iqq|nbl|family|smash|family)$/i, '')

    # Remover caracteres especiales y espacios extra
    normalized = normalized.gsub(/[^\w\s]/, '').strip.squeeze(' ')

    # Si el nombre normalizado es muy corto (menos de 2 caracteres), usar el original
    normalized.length >= 2 ? normalized : name.downcase.gsub(/[^\w\s]/, '').strip.squeeze(' ')
  end

  def names_are_similar?(name1, name2, original1, original2)
    return false if name1.blank? || name2.blank?
    return false if name1 == name2 # Exactamente iguales después de normalización

    # Filtro temprano: si los nombres son muy diferentes en longitud, skip
    length_ratio = [ name1.length, name2.length ].min.to_f / [ name1.length, name2.length ].max
    return false if length_ratio < 0.4 # Nombres muy diferentes en longitud

    # Métricas de similitud
    levenshtein_ratio = 1.0 - (levenshtein_distance(name1, name2).to_f / [ name1.length, name2.length ].max)
    jaccard_ratio = jaccard_similarity(name1.split, name2.split)

    # Casos especiales: uno contiene al otro
    contains_ratio = if name1.length > name2.length
      name2.length > 0 ? (name1.include?(name2) ? 1.0 : 0.0) : 0.0
    else
      name1.length > 0 ? (name2.include?(name1) ? 1.0 : 0.0) : 0.0
    end

    # Verificar si los nombres originales son muy similares (considerando prefijos)
    original_similar = original_prefix_similarity(original1, original2)

    # Combinar métricas
    max_similarity = [ levenshtein_ratio, jaccard_ratio, contains_ratio, original_similar ].max

    max_similarity >= SIMILARITY_THRESHOLD
  end

  def original_prefix_similarity(name1, name2)
    return 0.0 if name1.blank? || name2.blank?

    # Extraer la parte "core" del nombre (sin prefijos)
    core1 = extract_core_name(name1)
    core2 = extract_core_name(name2)

    return 0.0 if core1.blank? || core2.blank?

    # Si los cores son iguales, alta similitud
    return 1.0 if core1.downcase == core2.downcase

    # Calcular similitud entre cores
    1.0 - (levenshtein_distance(core1.downcase, core2.downcase).to_f / [ core1.length, core2.length ].max)
  end

  def extract_core_name(name)
    # Remover prefijos comunes de equipos/regiones
    core = name.gsub(/^(sf|cl|scl|vlp|anf|tmc|iqq|nbl|family|smash|family)\s*[\|\-\s]+/i, '')
    core = core.gsub(/[\|\-\s]*\s*(sf|cl|scl|vlp|anf|tmc|iqq|nbl|family|smash|family)$/i, '')
    core.strip
  end

  def levenshtein_distance(str1, str2)
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i-1] == str2[j-1] ? 0 : 1
        matrix[i][j] = [
          matrix[i-1][j] + 1,     # deletion
          matrix[i][j-1] + 1,     # insertion
          matrix[i-1][j-1] + cost # substitution
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end

  def jaccard_similarity(set1, set2)
    return 0.0 if set1.empty? && set2.empty?

    intersection = (set1 & set2).size
    union = (set1 | set2).size

    intersection.to_f / union
  end

  def analyze_group(group, group_number)
    puts "\n🔍 GRUPO #{group_number}: #{group.map(&:entrant_name).join(', ')}"
    puts "-" * 60

    # Ordenar por actividad (más eventos primero)
    sorted_group = group.sort_by { |p| -calculate_activity_score(p) }

    base_candidate = sorted_group.first
    merge_candidates = sorted_group[1..-1]

    puts "👑 CANDIDATO BASE (mayor actividad):"
    display_player_info(base_candidate, "  ")

    puts "\n🔄 CANDIDATOS PARA MERGE:"
    merge_candidates.each_with_index do |player, index|
      puts "\n  #{index + 1}. #{player.entrant_name}:"
      display_player_info(player, "     ")

      # Calcular score de confianza para el merge
      confidence = calculate_merge_confidence(base_candidate, player)
      puts "     🎯 Confianza de merge: #{(confidence * 100).round(1)}%"

      if confidence >= 0.7
        puts "     ✅ RECOMENDADO PARA MERGE"
        @potential_duplicates << {
          group_number: group_number,
          base_player: base_candidate,
          merge_candidate: player,
          confidence: confidence,
          activity_difference: calculate_activity_score(base_candidate) - calculate_activity_score(player)
        }
      else
        puts "     ⚠️  REVISAR MANUALMENTE"
      end
    end

    puts "\n" + "="*60
  end

  def display_player_info(player, indent = "")
    events_count = player.events_count
    tournaments_count = player.tournaments_count
    recent_tournament = player.recent_tournament
    has_account = player.user_id.present?
    has_team = player.primary_team_optimized.present?
    team_name = has_team ? player.primary_team_optimized.name : "Sin equipo"

    puts "#{indent}📊 #{player.entrant_name} (ID: #{player.id})"
    puts "#{indent}   • Eventos: #{events_count}"
    puts "#{indent}   • Torneos: #{tournaments_count}"
    puts "#{indent}   • Cuenta: #{has_account ? '✅ Sí' : '❌ No'} #{has_account ? "(user_id: #{player.user_id})" : "(start_gg_id: #{player.start_gg_id})"}"
    puts "#{indent}   • Equipo: #{team_name}"
    puts "#{indent}   • Último torneo: #{recent_tournament&.name || 'Ninguno'}"
    puts "#{indent}   • Score actividad: #{calculate_activity_score(player)}"

    if player.user.present?
      puts "#{indent}   • Usuario: #{player.user.display_name} (#{player.user.email})"
    elsif player.user_id.present?
      puts "#{indent}   • Usuario: ⚠️ User ID #{player.user_id} no encontrado"
    end
  end

  def calculate_activity_score(player)
    # Score basado en múltiples factores
    events_score = player.events_count * 10
    tournaments_score = player.tournaments_count * 25
    account_bonus = player.user_id.present? ? 50 : 0
    team_bonus = player.primary_team_optimized.present? ? 25 : 0

    # Bonus por actividad reciente (últimos 6 meses)
    recent_activity = player.events.joins(:tournament)
                           .where('tournaments.start_at >= ?', 6.months.ago)
                           .count
    recent_bonus = recent_activity * 5

    events_score + tournaments_score + account_bonus + team_bonus + recent_bonus
  end

  def calculate_merge_confidence(base_player, merge_candidate)
    confidence_factors = []

    # Factor 1: Similitud de nombres (ya verificado, pero refinamos)
    name_similarity = original_prefix_similarity(base_player.entrant_name, merge_candidate.entrant_name)
    confidence_factors << name_similarity * 0.4

    # Factor 2: Diferencia de actividad (menos diferencia = más confianza)
    base_activity = calculate_activity_score(base_player)
    candidate_activity = calculate_activity_score(merge_candidate)
    activity_ratio = candidate_activity.to_f / [ base_activity, 1 ].max
    activity_confidence = activity_ratio > 0.1 ? activity_ratio : 0.1 # Mínimo 10%
    confidence_factors << activity_confidence * 0.3

    # Factor 3: Presencia de información adicional consistente
    info_consistency = 0.0
    total_checks = 0

    # Verificar país
    if base_player.country.present? && merge_candidate.country.present?
      info_consistency += (base_player.country == merge_candidate.country ? 1.0 : 0.0)
      total_checks += 1
    end

    # Verificar equipo (si ambos tienen)
    if base_player.primary_team_optimized.present? && merge_candidate.primary_team_optimized.present?
      info_consistency += (base_player.primary_team_optimized == merge_candidate.primary_team_optimized ? 1.0 : 0.0)
      total_checks += 1
    end

    # Verificar Twitter (si ambos tienen)
    if base_player.twitter_handle.present? && merge_candidate.twitter_handle.present?
      info_consistency += (base_player.twitter_handle.downcase == merge_candidate.twitter_handle.downcase ? 1.0 : 0.0)
      total_checks += 1
    end

    info_confidence = total_checks > 0 ? info_consistency / total_checks : 0.5
    confidence_factors << info_confidence * 0.2

    # Factor 4: Penalty por tener cuenta ambos (menos probable que sean la misma persona)
    if base_player.user_id.present? && merge_candidate.user_id.present?
      confidence_factors << 0.1 # Penalty significativo
    else
      confidence_factors << 0.1 # Bonus neutro
    end

    confidence_factors.sum
  end

  def generate_summary
    puts "\n📋 RESUMEN DEL ANÁLISIS"
    puts "=" * 50
    puts "🔍 Duplicados potenciales encontrados: #{@potential_duplicates.size}"

    if @potential_duplicates.any?
      high_confidence = @potential_duplicates.select { |d| d[:confidence] >= 0.8 }
      medium_confidence = @potential_duplicates.select { |d| d[:confidence] >= 0.7 && d[:confidence] < 0.8 }

      puts "  • Alta confianza (≥80%): #{high_confidence.size}"
      puts "  • Confianza media (70-79%): #{medium_confidence.size}"

      total_events_to_merge = @potential_duplicates.sum { |d| d[:merge_candidate].events_count }
      puts "  • Total eventos a transferir: #{total_events_to_merge}"

      puts "\n🏆 TOP 5 RECOMENDACIONES:"
      @potential_duplicates
        .sort_by { |d| -d[:confidence] }
        .first(5)
        .each_with_index do |duplicate, index|
          puts "  #{index + 1}. #{duplicate[:merge_candidate].entrant_name} → #{duplicate[:base_player].entrant_name} (#{(duplicate[:confidence] * 100).round(1)}%)"
        end
    else
      puts "✅ No se encontraron duplicados con suficiente confianza para recomendar merge automático."
    end
  end

  def generate_csv_report
    puts "\n📄 Generando reporte CSV..."

    # Usar Time.now para compatibilidad
    time_method = defined?(Time.current) ? Time.current : Time.now
    CSV.open("duplicate_players_analysis_#{time_method.strftime('%Y%m%d_%H%M%S')}.csv", "wb") do |csv|
      csv << [
        "Grupo",
        "Base Player ID",
        "Base Player Name",
        "Base Player Events",
        "Base Player Account",
        "Merge Candidate ID",
        "Merge Candidate Name",
        "Merge Candidate Events",
        "Merge Candidate Account",
        "Confidence %",
        "Activity Difference",
        "Recommendation"
      ]

      @potential_duplicates.each do |duplicate|
        csv << [
          duplicate[:group_number],
          duplicate[:base_player].id,
          duplicate[:base_player].entrant_name,
          duplicate[:base_player].events_count,
          duplicate[:base_player].user_id.present? ? "Sí" : "No",
          duplicate[:merge_candidate].id,
          duplicate[:merge_candidate].entrant_name,
          duplicate[:merge_candidate].events_count,
          duplicate[:merge_candidate].user_id.present? ? "Sí" : "No",
          (duplicate[:confidence] * 100).round(1),
          duplicate[:activity_difference],
          duplicate[:confidence] >= 0.8 ? "AUTO MERGE" : "REVISAR"
        ]
      end
    end

    puts "✅ Reporte guardado: duplicate_players_analysis_#{time_method.strftime('%Y%m%d_%H%M%S')}.csv"
  end
end

# Ejecutar análisis
if __FILE__ == $0
  analyzer = DuplicatePlayersAnalyzer.new
  analyzer.analyze
end
