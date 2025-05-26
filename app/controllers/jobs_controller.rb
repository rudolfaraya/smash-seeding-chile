class JobsController < ApplicationController
  def index
    # Redirigir al panel de Mission Control
    redirect_to "/jobs"
  end

  def enqueue_update_players
    job = UpdatePlayersJob.perform_later(
      batch_size: params[:batch_size]&.to_i || 25,
      delay_between_batches: params[:delay_between_batches]&.to_i&.seconds || 45.seconds,
      force_update: params[:force_update] == 'true'
    )
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          message: "Job de actualización de jugadores encolado",
          job_id: job.job_id
        } 
      }
      format.html { 
        redirect_to "/jobs", notice: "Job de actualización de jugadores encolado exitosamente" 
      }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          error: e.message 
        }, status: :unprocessable_entity 
      }
      format.html { 
        redirect_to "/jobs", alert: "Error al encolar job: #{e.message}" 
      }
    end
  end

  def enqueue_sync_tournament
    tournament_id = params[:tournament_id]
    
    unless tournament_id.present?
      return render json: { success: false, error: "ID de torneo requerido" }, status: :bad_request
    end

    job = SyncTournamentJob.perform_later(tournament_id.to_i)
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          message: "Job de sincronización de torneo encolado",
          job_id: job.job_id
        } 
      }
      format.html { 
        redirect_to "/jobs", notice: "Job de sincronización encolado exitosamente" 
      }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          error: e.message 
        }, status: :unprocessable_entity 
      }
      format.html { 
        redirect_to "/jobs", alert: "Error al encolar job: #{e.message}" 
      }
    end
  end

  def enqueue_notification
    message = params[:message]
    recipient_type = params[:recipient_type] || 'all'
    
    unless message.present?
      return render json: { success: false, error: "Mensaje requerido" }, status: :bad_request
    end

    job = SendNotificationJob.perform_later(message, recipient_type)
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          message: "Job de notificación encolado",
          job_id: job.job_id
        } 
      }
      format.html { 
        redirect_to "/jobs", notice: "Job de notificación encolado exitosamente" 
      }
    end
  rescue StandardError => e
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          error: e.message 
        }, status: :unprocessable_entity 
      }
      format.html { 
        redirect_to "/jobs", alert: "Error al encolar job: #{e.message}" 
      }
    end
  end
end 