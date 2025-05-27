namespace :sync do
  desc "Encolar job de sincronización general de torneos"
  task tournaments: :environment do
    puts "🏆 Encolando job de sincronización general de torneos..."
    job = SyncTournamentsJob.perform_later
    puts "✅ Job encolado con ID: #{job.job_id}"
    puts "🔍 Puedes monitorear el progreso en Mission Control: /jobs"
  end

  desc "Encolar job de sincronización de nuevos torneos"
  task new_tournaments: :environment do
    puts "🆕 Encolando job de sincronización de nuevos torneos..."
    job = SyncNewTournamentsJob.perform_later
    puts "✅ Job encolado con ID: #{job.job_id}"
    puts "🔍 Puedes monitorear el progreso en Mission Control: /jobs"
  end

  desc "Encolar job de sincronización masiva de torneos (limit opcional)"
  task :all_tournaments, [:limit] => :environment do |task, args|
    limit = args[:limit]&.to_i
    puts "🚀 Encolando job de sincronización masiva de torneos..."
    puts "📊 Límite: #{limit || 'Sin límite'}"
    
    job = SyncAllTournamentsJob.perform_later({ limit: limit })
    puts "✅ Job encolado con ID: #{job.job_id}"
    puts "🔍 Puedes monitorear el progreso en Mission Control: /jobs"
  end

  desc "Encolar job de sincronización de eventos para un torneo específico"
  task :tournament_events, [:tournament_id] => :environment do |task, args|
    tournament_id = args[:tournament_id]
    
    unless tournament_id
      puts "❌ Error: Debes proporcionar un tournament_id"
      puts "Uso: rails sync:tournament_events[123]"
      exit 1
    end

    tournament = Tournament.find_by(id: tournament_id)
    unless tournament
      puts "❌ Error: Torneo con ID #{tournament_id} no encontrado"
      exit 1
    end

    puts "📋 Encolando job de sincronización de eventos para: #{tournament.name}"
    job = SyncTournamentEventsJob.perform_later(tournament_id)
    puts "✅ Job encolado con ID: #{job.job_id}"
    puts "🔍 Puedes monitorear el progreso en Mission Control: /jobs"
  end

  desc "Encolar job de sincronización de seeds para un evento específico"
  task :event_seeds, [:event_id, :force, :update_players] => :environment do |task, args|
    event_id = args[:event_id]
    force = args[:force] == 'true'
    update_players = args[:update_players] == 'true'
    
    unless event_id
      puts "❌ Error: Debes proporcionar un event_id"
      puts "Uso: rails sync:event_seeds[123] o rails sync:event_seeds[123,true,true]"
      exit 1
    end

    event = Event.find_by(id: event_id)
    unless event
      puts "❌ Error: Evento con ID #{event_id} no encontrado"
      exit 1
    end

    puts "🌱 Encolando job de sincronización de seeds para: #{event.name} (#{event.tournament.name})"
    puts "🔄 Force: #{force}, Update Players: #{update_players}"
    
    job = SyncEventSeedsJob.perform_later(event_id, { force: force, update_players: update_players })
    puts "✅ Job encolado con ID: #{job.job_id}"
    puts "🔍 Puedes monitorear el progreso en Mission Control: /jobs"
  end

  desc "Encolar job de sincronización completa de un torneo (eventos + seeds)"
  task :tournament_complete, [:tournament_id, :force] => :environment do |task, args|
    tournament_id = args[:tournament_id]
    force = args[:force] == 'true'
    
    unless tournament_id
      puts "❌ Error: Debes proporcionar un tournament_id"
      puts "Uso: rails sync:tournament_complete[123] o rails sync:tournament_complete[123,true]"
      exit 1
    end

    tournament = Tournament.find_by(id: tournament_id)
    unless tournament
      puts "❌ Error: Torneo con ID #{tournament_id} no encontrado"
      exit 1
    end

    puts "🏆 Encolando job de sincronización completa para: #{tournament.name}"
    puts "🔄 Force: #{force}"
    
    job = SyncTournamentJob.perform_later(tournament_id, { force: force })
    puts "✅ Job encolado con ID: #{job.job_id}"
    puts "🔍 Puedes monitorear el progreso en Mission Control: /jobs"
  end

  desc "Encolar job de actualización de jugadores"
  task :players, [:batch_size, :force] => :environment do |task, args|
    batch_size = args[:batch_size]&.to_i || 25
    force = args[:force] == 'true'
    
    puts "👥 Encolando job de actualización de jugadores..."
    puts "📦 Batch size: #{batch_size}, Force: #{force}"
    
    job = UpdatePlayersJob.perform_later({ 
      batch_size: batch_size, 
      force_update: force 
    })
    puts "✅ Job encolado con ID: #{job.job_id}"
    puts "🔍 Puedes monitorear el progreso en Mission Control: /jobs"
  end

  desc "Mostrar estado de la cola de jobs"
  task status: :environment do
    puts "📊 ESTADO DE LA COLA DE JOBS"
    puts "=" * 50
    
    # Contar jobs por estado
    enqueued = SolidQueue::Job.where(finished_at: nil).count
    finished = SolidQueue::Job.where.not(finished_at: nil).count
    failed = SolidQueue::FailedExecution.count
    
    puts "🔄 Jobs en cola: #{enqueued}"
    puts "✅ Jobs completados: #{finished}"
    puts "❌ Jobs fallidos: #{failed}"
    puts
    
    # Mostrar jobs recientes
    puts "📋 JOBS RECIENTES (últimos 10):"
    puts "-" * 30
    
    SolidQueue::Job.order(created_at: :desc).limit(10).each do |job|
      status = job.finished_at ? "✅" : "🔄"
      puts "#{status} #{job.class_name} - #{job.created_at.strftime('%H:%M:%S')}"
    end
    
    if failed > 0
      puts
      puts "❌ JOBS FALLIDOS:"
      puts "-" * 20
      SolidQueue::FailedExecution.order(created_at: :desc).limit(5).each do |failed_job|
        puts "❌ #{failed_job.job.class_name} - #{failed_job.error}"
      end
    end
  end
end 