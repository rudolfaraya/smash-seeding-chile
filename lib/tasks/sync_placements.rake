namespace :placements do
  desc "Sincronizar placements de un evento específico"
  task :sync_event, [ :event_id ] => :environment do |t, args|
    event_id = args[:event_id]

    unless event_id
      puts "❌ Error: Debes especificar un event_id"
      puts "Uso: rake placements:sync_event[123]"
      exit 1
    end

    event = Event.find_by(id: event_id)
    unless event
      puts "❌ Error: No se encontró evento con ID #{event_id}"
      exit 1
    end

    unless event.start_gg_event_id.present?
      puts "❌ Error: El evento '#{event.name}' no tiene start_gg_event_id"
      exit 1
    end

    puts "🏆 Sincronizando placements para: #{event.tournament.name} - #{event.name}"
    puts "🆔 Event ID: #{event.start_gg_event_id}"

    begin
      event.fetch_and_save_placements(force: true)
      puts "✅ Placements sincronizados exitosamente"
    rescue => e
      puts "❌ Error sincronizando placements: #{e.message}"
      exit 1
    end
  end

  desc "Sincronizar placements de todos los eventos de un torneo"
  task :sync_tournament, [ :tournament_id ] => :environment do |t, args|
    tournament_id = args[:tournament_id]

    unless tournament_id
      puts "❌ Error: Debes especificar un tournament_id"
      puts "Uso: rake placements:sync_tournament[123]"
      exit 1
    end

    tournament = Tournament.find_by(id: tournament_id)
    unless tournament
      puts "❌ Error: No se encontró torneo con ID #{tournament_id}"
      exit 1
    end

    events = tournament.events.where.not(start_gg_event_id: nil)

    if events.empty?
      puts "⚠️ No hay eventos con start_gg_event_id en el torneo '#{tournament.name}'"
      exit 0
    end

    puts "🏆 Sincronizando placements para torneo: #{tournament.name}"
    puts "📊 Eventos a procesar: #{events.count}"

    success_count = 0
    error_count = 0

    events.each_with_index do |event, index|
      puts "\n📍 [#{index + 1}/#{events.count}] #{event.name}"

      begin
        event.fetch_and_save_placements(force: true)
        puts "✅ Sincronizado exitosamente"
        success_count += 1
      rescue => e
        puts "❌ Error: #{e.message}"
        error_count += 1
      end

      # Rate limiting
      sleep(1) unless index == events.count - 1
    end

    puts "\n📋 RESUMEN:"
    puts "✅ Eventos sincronizados: #{success_count}"
    puts "❌ Eventos con errores: #{error_count}"
  end

  desc "Sincronizar placements históricos (últimos 6 meses)"
  task sync_historical: :environment do
    puts "🏆 Sincronizando placements históricos (últimos 6 meses)..."

    system("ruby scripts/sync_historical_placements.rb")
  end

  desc "Sincronizar placements de TODA la historia (sin límite temporal)"
  task sync_all_history: :environment do
    puts "🏆 Sincronizando placements de TODA la historia..."
    puts "⚠️  ADVERTENCIA: Esto puede procesar miles de eventos y tomar horas"
    puts ""

    print "¿Estás seguro de que quieres continuar? (s/N): "
    response = STDIN.gets.chomp.downcase

    if response == "s" || response == "si" || response == "sí"
      puts "🚀 Iniciando sincronización completa..."
      system("ruby scripts/sync_historical_placements.rb --all-history")
    else
      puts "❌ Sincronización cancelada"
    end
  end

  desc "Sincronizar placements históricos con opciones personalizadas"
  task sync_historical_advanced: :environment do
    puts "🏆 Sincronización avanzada de placements históricos"
    puts ""
    puts "Opciones disponibles:"
    puts "  --force    : Forzar actualización incluso si ya existen placements"
    puts "  --dry-run  : Simular sin hacer cambios reales"
    puts "  --delay N  : Delay en segundos entre requests (default: 1.0)"
    puts ""
    puts "Ejecuta: ruby scripts/sync_historical_placements.rb [opciones]"
  end

  desc "Analizar rendimientos vs seeds"
  task analyze_performance: :environment do
    puts "📊 ANÁLISIS DE RENDIMIENTO VS SEEDS"
    puts "=" * 50

    # Verificar si existe la columna placement
    unless EventSeed.column_names.include?("placement")
      puts "❌ Error: La columna 'placement' no existe en event_seeds"
      puts "💡 Ejecuta las migraciones: rails db:migrate"
      exit 1
    end

    total_with_data = EventSeed.where("seed_num IS NOT NULL AND placement IS NOT NULL").count
    total_seeds = EventSeed.count

    if total_with_data == 0
      puts "⚠️ No hay datos de placement para analizar"
      puts "💡 Ejecuta 'rake placements:sync_historical' para sincronizar datos"
      puts ""
      puts "📈 ESTADÍSTICAS ACTUALES:"
      puts "  • Total event seeds: #{total_seeds}"
      puts "  • Con datos de placement: 0"
      puts "  • Cobertura: 0.0%"

      # Mostrar algunos ejemplos de registros sin placement
      sample_seeds = EventSeed.joins(player: [], event: :tournament)
                             .select("event_seeds.*, players.entrant_name, events.name as event_name, tournaments.name as tournament_name")
                             .limit(5)

      puts ""
      puts "🔍 EJEMPLOS DE REGISTROS SIN PLACEMENT:"
      sample_seeds.each do |seed|
        puts "  • #{seed.entrant_name} - #{seed.tournament_name} - #{seed.event_name}"
        puts "    Seed: #{seed.seed_num || 'N/A'}, Placement: #{seed.placement || 'N/A'}"
      end

      exit 0
    end

    puts "📈 ESTADÍSTICAS GENERALES:"
    puts "  • Total event seeds: #{total_seeds}"
    puts "  • Con datos completos: #{total_with_data}"
    puts "  • Cobertura: #{((total_with_data.to_f / total_seeds) * 100).round(1)}%"
    puts ""

    exceeded = EventSeed.where("seed_num IS NOT NULL AND placement IS NOT NULL AND placement < seed_num").count
    met = EventSeed.where("seed_num IS NOT NULL AND placement IS NOT NULL AND placement = seed_num").count
    under = EventSeed.where("seed_num IS NOT NULL AND placement IS NOT NULL AND placement > seed_num").count

    puts "🎯 ANÁLISIS DE RENDIMIENTO:"
    puts "  • Superaron expectativas: #{exceeded} (#{percentage(exceeded, total_with_data)}%)"
    puts "  • Cumplieron expectativas: #{met} (#{percentage(met, total_with_data)}%)"
    puts "  • No cumplieron expectativas: #{under} (#{percentage(under, total_with_data)}%)"
    puts ""

    # Top mejores rendimientos
    puts "🏆 TOP 10 MEJORES RENDIMIENTOS:"
    top_performers = EventSeed.where("seed_num IS NOT NULL AND placement IS NOT NULL")
                             .select("event_seeds.*, players.entrant_name, events.name as event_name, tournaments.name as tournament_name")
                             .joins(player: [], event: :tournament)
                             .order(Arel.sql("(seed_num - placement) DESC"))
                             .limit(10)

    if top_performers.empty?
      puts "  ⚠️ No hay registros con datos completos para mostrar"
    else
      top_performers.each_with_index do |seed, index|
        improvement = seed.seed_num - seed.placement
        puts "  #{index + 1}. #{seed.entrant_name} - Seed #{seed.seed_num} → #{seed.placement}° (+#{improvement})"
        puts "     #{seed.tournament_name} - #{seed.event_name}"
      end
    end

    puts ""

    # Top peores rendimientos
    puts "📉 TOP 10 PEORES RENDIMIENTOS:"
    worst_performers = EventSeed.where("seed_num IS NOT NULL AND placement IS NOT NULL")
                               .select("event_seeds.*, players.entrant_name, events.name as event_name, tournaments.name as tournament_name")
                               .joins(player: [], event: :tournament)
                               .order(Arel.sql("(placement - seed_num) DESC"))
                               .limit(10)

    if worst_performers.empty?
      puts "  ⚠️ No hay registros con datos completos para mostrar"
    else
      worst_performers.each_with_index do |seed, index|
        decline = seed.placement - seed.seed_num
        puts "  #{index + 1}. #{seed.entrant_name} - Seed #{seed.seed_num} → #{seed.placement}° (-#{decline})"
        puts "     #{seed.tournament_name} - #{seed.event_name}"
      end
    end
  end

  desc "Analizar factores de rendimiento por rondas (nuevo sistema)"
  task analyze_round_performance: :environment do
    puts "🎯 ANÁLISIS DE FACTORES DE RENDIMIENTO POR RONDAS"
    puts "=" * 55

    # Estadísticas generales
    total_seeds = EventSeed.count
    seeds_with_data = EventSeed.with_complete_data.count
    coverage = total_seeds > 0 ? (seeds_with_data.to_f / total_seeds * 100).round(1) : 0

    puts "📊 ESTADÍSTICAS GENERALES:"
    puts "  • Total event seeds: #{total_seeds}"
    puts "  • Con datos completos: #{seeds_with_data}"
    puts "  • Cobertura: #{coverage}%"
    puts

    if seeds_with_data == 0
      puts "❌ No hay datos de placements para analizar"
      puts "   Usa: rake placements:sync_historical"
      next
    end

    # Análisis por factores
    seeds = EventSeed.with_complete_data.includes(:player, event: :tournament)

    # Agrupar por factor de rendimiento
    factor_groups = seeds.group_by { |s| s.round_performance_factor }.transform_values(&:count)

    puts "🎲 DISTRIBUCIÓN DE FACTORES:"
    factor_groups.sort_by { |k, v| k || 0 }.each do |factor, count|
      percentage = (count.to_f / seeds_with_data * 100).round(1)
      factor_display = factor.nil? ? "Sin datos" : (factor == 0 ? "0 (cumplió)" : (factor > 0 ? "+#{factor}" : factor.to_s))
      puts "  • Factor #{factor_display}: #{count} jugadores (#{percentage}%)"
    end
    puts

    # Top mejores rendimientos
    puts "🔥 TOP 10 MEJORES FACTORES DE RENDIMIENTO:"
    top_performers = seeds.select { |s| s.round_performance_factor && s.round_performance_factor > 0 }
                          .sort_by { |s| [ -s.round_performance_factor, s.seed_num ] }
                          .first(10)

    if top_performers.any?
      top_performers.each_with_index do |seed, index|
        factor = seed.round_performance_factor
        icon_data = seed.performance_icon_data
        puts "  #{index + 1}. #{seed.player.entrant_name} - #{icon_data[:icon]}"
        puts "     Seed #{seed.seed_num} → #{seed.placement}° (#{seed.event.tournament.name})"
      end
    else
      puts "  No hay jugadores que hayan superado expectativas"
    end
    puts

    # Top peores rendimientos
    puts "❄️ TOP 10 PEORES FACTORES DE RENDIMIENTO:"
    worst_performers = seeds.select { |s| s.round_performance_factor && s.round_performance_factor < 0 }
                            .sort_by { |s| [ s.round_performance_factor, -s.seed_num ] }
                            .first(10)

    if worst_performers.any?
      worst_performers.each_with_index do |seed, index|
        factor = seed.round_performance_factor
        icon_data = seed.performance_icon_data
        puts "  #{index + 1}. #{seed.player.entrant_name} - #{icon_data[:icon]}"
        puts "     Seed #{seed.seed_num} → #{seed.placement}° (#{seed.event.tournament.name})"
      end
    else
      puts "  No hay jugadores que hayan rendido por debajo de expectativas"
    end
    puts

    # Análisis de precisión de expectativas
    exact_matches = seeds.select { |s| s.round_performance_factor == 0 }.count
    if exact_matches > 0
      accuracy = (exact_matches.to_f / seeds_with_data * 100).round(1)
      puts "🎯 PRECISIÓN DE SEEDS:"
      puts "  • Jugadores que cumplieron exactamente: #{exact_matches} (#{accuracy}%)"
      puts "  • Sistema de seeding tiene #{accuracy}% de precisión"
    end
  end

  private

  def percentage(part, total)
    return 0 if total == 0
    ((part.to_f / total) * 100).round(1)
  end
end
