namespace :events do
  desc "Actualizar start_gg_event_id faltantes en todos los eventos"
  task :update_missing_start_gg_ids, [ :dry_run, :delay ] => :environment do |t, args|
    dry_run = args[:dry_run] == "true" || args[:dry_run] == "dry-run"
    delay = args[:delay]&.to_f || 1.5

    puts "🔧 ACTUALIZACIÓN DE start_gg_event_id FALTANTES"
    puts "=" * 60
    puts "🔍 Modo: #{dry_run ? 'DRY RUN (simulación)' : 'PRODUCCIÓN'}"
    puts "⏱️  Delay entre requests: #{delay} segundos"
    puts

    # Ejecutar el script directamente
    script_path = Rails.root.join("scripts", "update_missing_start_gg_event_ids.rb")

    args_str = []
    args_str << "--dry-run" if dry_run
    args_str << "--delay #{delay}" if delay != 1.5

    system("ruby #{script_path} #{args_str.join(' ')}")
  end

  desc "Mostrar estadísticas de start_gg_event_id"
  task show_start_gg_id_stats: :environment do
    total_events = Event.count
    events_with_ids = Event.where.not(start_gg_event_id: nil).count
    events_without_ids = Event.where(start_gg_event_id: nil).count
    coverage = total_events > 0 ? (events_with_ids.to_f / total_events * 100).round(1) : 0

    puts "📊 ESTADÍSTICAS DE start_gg_event_id"
    puts "=" * 45
    puts "📈 Total eventos: #{total_events}"
    puts "✅ Con start_gg_event_id: #{events_with_ids}"
    puts "❌ Sin start_gg_event_id: #{events_without_ids}"
    puts "📊 Cobertura: #{coverage}%"
    puts

    if events_without_ids > 0
      puts "⚠️  Para actualizar los eventos faltantes:"
      puts "   rake 'events:update_missing_start_gg_ids[dry-run]'  # Simular"
      puts "   rake 'events:update_missing_start_gg_ids[false]'    # Ejecutar"
      puts "   rake 'events:update_missing_start_gg_ids[false,2.0]' # Con delay personalizado"
    else
      puts "🎉 ¡Todos los eventos tienen start_gg_event_id!"
    end
  end
end
