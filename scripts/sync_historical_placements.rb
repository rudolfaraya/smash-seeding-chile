#!/usr/bin/env ruby
# Script para sincronizar placements históricos de todos los eventos

# Cargar entorno de Rails
unless defined?(Rails)
  require_relative '../config/environment'
end

class HistoricalPlacementsSyncer
  def initialize(options = {})
    @force = options[:force] || false
    @dry_run = options[:dry_run] || false
    @delay = options[:delay] || 1.0 # segundos entre requests
    @all_history = options[:all_history] || false
    @synced_count = 0
    @error_count = 0
    @skipped_count = 0
  end

  def sync_all
    puts "🏆 SINCRONIZACIÓN HISTÓRICA DE PLACEMENTS"
    puts "=" * 50

    puts "⚙️ Configuración:"
    puts "  • Modo: #{@dry_run ? 'DRY RUN (sin cambios)' : 'EJECUCIÓN REAL'}"
    puts "  • Forzar actualización: #{@force ? 'Sí' : 'No'}"
    puts "  • Alcance temporal: #{@all_history ? 'TODA LA HISTORIA' : 'Últimos 6 meses'}"
    puts "  • Delay entre requests: #{@delay}s"
    puts ""

    # Obtener eventos elegibles
    events = get_eligible_events

    puts "📊 Eventos encontrados:"
    puts "  • Total de eventos: #{Event.count}"
    puts "  • Eventos con start_gg_event_id: #{Event.where.not(start_gg_event_id: nil).count}"
    puts "  • Eventos elegibles para sincronizar: #{events.count}"
    puts ""

    if events.empty?
      puts "✅ No hay eventos para sincronizar placements"
      return
    end

    puts "🚀 Iniciando sincronización..."
    puts ""

    events.each_with_index do |event, index|
      sync_event_placements(event, index + 1, events.count)

      # Delay entre requests para respetar rate limits
      sleep(@delay) unless index == events.count - 1
    end

    generate_summary
  end

  private

  def get_eligible_events
    base_scope = Event.joins(:tournament)
                     .where.not(start_gg_event_id: nil)
                     .includes(:tournament, :event_seeds)

    # Aplicar filtro temporal solo si no se especifica --all-history
    unless @all_history
      base_scope = base_scope.where('tournaments.start_at > ?', 6.months.ago)
    end

    if @force
      # Sincronizar todos los eventos elegibles
      base_scope
    else
      # Solo eventos que no tienen placements o no se han sincronizado antes
      base_scope.where(placements_last_synced_at: nil)
                .or(base_scope.where('event_seeds.placement IS NULL'))
    end.distinct
  end

  def sync_event_placements(event, current, total)
    puts "📍 [#{current}/#{total}] #{event.tournament.name} - #{event.name}"
    puts "    🆔 Event ID: #{event.start_gg_event_id}"
    puts "    📅 Fecha: #{event.tournament.start_at&.strftime('%d/%m/%Y') || 'N/A'}"

    # Verificar estado actual
    total_seeds = event.event_seeds.count
    seeds_with_placement = event.event_seeds.where.not(placement: nil).count

    puts "    📊 Seeds: #{total_seeds} (#{seeds_with_placement} con placement)"

    if !@force && seeds_with_placement > 0
      puts "    ⏭️  SALTADO: Ya tiene placements (usar --force para reemplazar)"
      @skipped_count += 1
      puts ""
      return
    end

    return if @dry_run

    begin
      # Sincronizar placements
      event.fetch_and_save_placements(force: @force)

      # Verificar resultados
      event.reload
      new_placement_count = event.event_seeds.where.not(placement: nil).count

      if new_placement_count > seeds_with_placement
        puts "    ✅ ÉXITO: #{new_placement_count - seeds_with_placement} nuevos placements agregados"
        @synced_count += 1
      else
        puts "    ⚠️  SIN CAMBIOS: No se agregaron nuevos placements"
        @skipped_count += 1
      end

    rescue => e
      puts "    ❌ ERROR: #{e.message}"
      @error_count += 1
    end

    puts ""
  end

  def generate_summary
    puts "📋 RESUMEN DE SINCRONIZACIÓN"
    puts "=" * 50
    puts "✅ Eventos sincronizados exitosamente: #{@synced_count}"
    puts "⏭️  Eventos saltados: #{@skipped_count}"
    puts "❌ Eventos con errores: #{@error_count}"
    puts ""

    if @synced_count > 0
      # Estadísticas globales después de la sincronización
      total_seeds_with_placement = EventSeed.where.not(placement: nil).count
      total_seeds = EventSeed.count

      puts "📊 ESTADÍSTICAS GLOBALES:"
      puts "  • Total event_seeds: #{total_seeds}"
      puts "  • Con placement: #{total_seeds_with_placement}"
      puts "  • Cobertura: #{((total_seeds_with_placement.to_f / total_seeds) * 100).round(1)}%"
      puts ""

      # Análisis de rendimiento general
      if total_seeds_with_placement > 0
        exceeded = EventSeed.exceeded_expectations.count
        met = EventSeed.met_expectations.count
        under = EventSeed.underperformed.count

        puts "🎯 ANÁLISIS DE RENDIMIENTO:"
        puts "  • Superaron expectativas: #{exceeded} (#{percentage(exceeded, total_seeds_with_placement)}%)"
        puts "  • Cumplieron expectativas: #{met} (#{percentage(met, total_seeds_with_placement)}%)"
        puts "  • No cumplieron expectativas: #{under} (#{percentage(under, total_seeds_with_placement)}%)"
      end
    end

    if @dry_run
      puts "💡 Esto fue un DRY RUN. Para ejecutar realmente, quita la opción --dry-run"
    end
  end

  def percentage(part, total)
    return 0 if total == 0
    ((part.to_f / total) * 100).round(1)
  end
end

# Ejecutar script si se llama directamente
if __FILE__ == $0
  require 'optparse'

  options = {}

  OptionParser.new do |opts|
    opts.banner = "Uso: ruby sync_historical_placements.rb [opciones]"

    opts.on("--force", "Forzar sincronización incluso si ya existen placements") do
      options[:force] = true
    end

    opts.on("--dry-run", "Simular la sincronización sin hacer cambios reales") do
      options[:dry_run] = true
    end

    opts.on("--delay SECONDS", Float, "Delay en segundos entre requests (default: 1.0)") do |delay|
      options[:delay] = delay
    end

    opts.on("--all-history", "Sincronizar toda la historia sin límite temporal") do
      options[:all_history] = true
    end

    opts.on("-h", "--help", "Mostrar esta ayuda") do
      puts opts
      exit
    end
  end.parse!

  syncer = HistoricalPlacementsSyncer.new(options)
  syncer.sync_all
end
