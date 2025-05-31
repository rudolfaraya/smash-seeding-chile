#!/usr/bin/env ruby

# Script para actualizar start_gg_event_id faltantes en eventos existentes
# Uso: ruby scripts/update_missing_start_gg_event_ids.rb [--dry-run] [--delay N]

require_relative '../config/environment'
require_relative '../lib/start_gg_queries'
require 'optparse'

class UpdateMissingStartGgEventIds
  def initialize(dry_run: false, delay: 1.5)
    @dry_run = dry_run
    @delay = delay
    @client = StartGgClient.new
    @stats = {
      total_events: 0,
      missing_event_ids: 0,
      updated: 0,
      errors: 0,
      skipped: 0
    }
  end

  def run
    puts "🔧 ACTUALIZACIÓN DE start_gg_event_id FALTANTES"
    puts "=" * 60
    puts "🔍 Modo: #{@dry_run ? 'DRY RUN (simulación)' : 'PRODUCCIÓN'}"
    puts "⏱️  Delay entre requests: #{@delay} segundos"
    puts

    # Obtener estadísticas iniciales
    analyze_current_state

    # Encontrar eventos sin start_gg_event_id
    events_to_update = find_events_missing_start_gg_id

    if events_to_update.empty?
      puts "✅ Todos los eventos ya tienen start_gg_event_id!"
      return
    end

    puts "📋 EVENTOS A PROCESAR:"
    puts "   • Total eventos sin start_gg_event_id: #{events_to_update.count}"
    puts "   • Tiempo estimado: #{estimate_time(events_to_update.count)} minutos"
    puts

    # Procesar eventos
    process_events(events_to_update)

    # Mostrar resumen final
    show_final_summary
  end

  private

  def analyze_current_state
    @stats[:total_events] = Event.count
    @stats[:missing_event_ids] = Event.where(start_gg_event_id: nil).count
    events_with_ids = Event.where.not(start_gg_event_id: nil).count

    puts "📊 ESTADO ACTUAL:"
    puts "   • Total eventos: #{@stats[:total_events]}"
    puts "   • Con start_gg_event_id: #{events_with_ids}"
    puts "   • Sin start_gg_event_id: #{@stats[:missing_event_ids]}"
    puts "   • Cobertura: #{(@stats[:total_events] > 0 ? (events_with_ids.to_f / @stats[:total_events] * 100).round(1) : 0)}%"
    puts
  end

  def find_events_missing_start_gg_id
    # Obtener eventos sin start_gg_event_id, incluyendo información del torneo
    Event.includes(:tournament)
         .where(start_gg_event_id: nil)
         .order('tournaments.start_at DESC')
  end

  def process_events(events)
    puts "🚀 INICIANDO PROCESAMIENTO..."
    puts

    events.each_with_index do |event, index|
      process_single_event(event, index + 1, events.count)

      # Pausa entre requests para respetar rate limits
      sleep(@delay) unless index == events.count - 1
    end
  end

  def process_single_event(event, current, total)
    tournament = event.tournament
    progress = "#{current}/#{total}"

    puts "⚡ [#{progress}] #{tournament.name} - #{event.name}"
    puts "   🆔 Tournament: #{tournament.slug}"
    puts "   🎯 Event: #{event.slug}"

    begin
      # Consultar la API para obtener eventos del torneo
      response = @client.query(
        StartGgQueries::EVENTS_QUERY,
        { tournamentSlug: tournament.slug },
        "TournamentEvents"
      )

      tournament_data = response["data"]["tournament"]

      if tournament_data.nil?
        puts "   ❌ Torneo no encontrado en start.gg"
        @stats[:errors] += 1
        return
      end

      events_data = tournament_data["events"] || []

      # Buscar el evento por slug
      matching_event = events_data.find { |e| e["slug"] == event.slug }

      if matching_event.nil?
        puts "   ⚠️  Evento no encontrado en start.gg"
        @stats[:skipped] += 1
        return
      end

      start_gg_event_id = matching_event["id"]

      if @dry_run
        puts "   🔍 [DRY RUN] Sería actualizado con start_gg_event_id: #{start_gg_event_id}"
      else
        event.update!(start_gg_event_id: start_gg_event_id)
        puts "   ✅ Actualizado con start_gg_event_id: #{start_gg_event_id}"
      end

      @stats[:updated] += 1

    rescue Faraday::ClientError => e
      handle_api_error(e, tournament.slug)
    rescue StandardError => e
      puts "   ❌ Error inesperado: #{e.message}"
      @stats[:errors] += 1
    end

    puts
  end

  def handle_api_error(error, tournament_slug)
    if error.response[:status] == 429
      puts "   ⏱️  Rate limit alcanzado, esperando 60 segundos..."
      sleep(60)
      @stats[:errors] += 1
    elsif error.response[:status] == 404
      puts "   ⚠️  Torneo no encontrado (404): #{tournament_slug}"
      @stats[:skipped] += 1
    else
      puts "   ❌ Error HTTP #{error.response[:status]}: #{error.message}"
      @stats[:errors] += 1
    end
  end

  def estimate_time(count)
    # Estimación conservadora incluyendo rate limits
    total_seconds = count * (@delay + 0.5) # +0.5 por overhead de procesamiento
    (total_seconds / 60.0).ceil
  end

  def show_final_summary
    puts "=" * 60
    puts "📊 RESUMEN FINAL"
    puts "=" * 60
    puts "✅ Eventos actualizados: #{@stats[:updated]}"
    puts "❌ Errores: #{@stats[:errors]}"
    puts "⏭️  Saltados (no encontrados): #{@stats[:skipped]}"
    puts "📈 Total procesados: #{@stats[:updated] + @stats[:errors] + @stats[:skipped]}"
    puts

    if @dry_run
      puts "🔍 MODO DRY RUN - No se realizaron cambios reales"
      puts "   Para aplicar los cambios, ejecuta sin --dry-run"
    else
      puts "🎉 ACTUALIZACIÓN COMPLETADA"

      # Mostrar estadísticas actualizadas
      puts
      puts "📊 ESTADO DESPUÉS DE ACTUALIZACIÓN:"
      new_missing = Event.where(start_gg_event_id: nil).count
      new_with_ids = Event.where.not(start_gg_event_id: nil).count
      puts "   • Con start_gg_event_id: #{new_with_ids}"
      puts "   • Sin start_gg_event_id: #{new_missing}"
      puts "   • Nueva cobertura: #{(@stats[:total_events] > 0 ? (new_with_ids.to_f / @stats[:total_events] * 100).round(1) : 0)}%"
    end
    puts
  end
end

# Parsear argumentos de línea de comandos
options = { dry_run: false, delay: 1.5 }

OptionParser.new do |opts|
  opts.banner = "Uso: ruby #{$0} [opciones]"

  opts.on("--dry-run", "Simular sin hacer cambios reales") do
    options[:dry_run] = true
  end

  opts.on("--delay SECONDS", Float, "Delay entre requests (default: 1.5)") do |delay|
    options[:delay] = delay
  end

  opts.on("-h", "--help", "Mostrar esta ayuda") do
    puts opts
    exit
  end
end.parse!

# Ejecutar el script
begin
  updater = UpdateMissingStartGgEventIds.new(
    dry_run: options[:dry_run],
    delay: options[:delay]
  )
  updater.run
rescue Interrupt
  puts "\n⏹️  Script interrumpido por el usuario"
  exit 1
rescue StandardError => e
  puts "\n❌ Error fatal: #{e.message}"
  puts e.backtrace.join("\n") if ENV['DEBUG']
  exit 1
end
