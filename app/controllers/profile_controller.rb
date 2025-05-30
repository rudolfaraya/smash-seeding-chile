class ProfileController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @player = current_user.player
    @player_request = current_user.pending_player_request || current_user.last_player_request
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    
    if @user.update(user_params)
      flash[:success] = "Perfil actualizado correctamente."
      redirect_to profile_path
    else
      flash.now[:alert] = "Error al actualizar el perfil: #{@user.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  end

  # Vista del player vinculado
  def player
    @player = current_user.player
    
    unless @player
      flash[:alert] = "No tienes un jugador vinculado a tu cuenta."
      redirect_to profile_path
      return
    end

    # Cargar estadísticas del player
    @stats = calculate_player_stats(@player)
    @recent_events = @player.events.joins(:tournament)
                            .includes(:tournament)
                            .order('tournaments.start_at DESC')
                            .limit(10)
    @teams = @player.teams.includes(:logo_image_attachment)
  end

  # Editar información del player (solo si está vinculado)
  def edit_player
    @player = current_user.player
    
    unless @player && current_user.can_edit_player?(@player)
      flash[:alert] = "No tienes permisos para editar este jugador."
      redirect_to profile_path
      return
    end
  end

  def update_player
    @player = current_user.player
    
    unless @player && current_user.can_edit_player?(@player)
      flash[:alert] = "No tienes permisos para editar este jugador."
      redirect_to profile_path
      return
    end

    if @player.update(player_params)
      flash[:success] = "Información del jugador actualizada correctamente."
      redirect_to profile_player_path
    else
      flash.now[:alert] = "Error al actualizar: #{@player.errors.full_messages.join(', ')}"
      render :edit_player, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email)
  end

  def player_params
    params.require(:player).permit(:bio, :city, :state, :country, :character_1, :skin_1, 
                                  :character_2, :skin_2, :character_3, :skin_3, 
                                  :twitter_handle, :gender_pronoun)
  end

  def calculate_player_stats(player)
    events = player.events.includes(:tournament)
    
    {
      total_tournaments: events.joins(:tournament).select('tournaments.id').distinct.count,
      total_events: events.count,
      characters_used: [], # Temporalmente vacío hasta implementar la relación
      recent_activity: events.joins(:tournament)
                            .where('tournaments.start_at >= ?', 6.months.ago)
                            .count,
      first_tournament: events.joins(:tournament)
                             .order('tournaments.start_at ASC')
                             .first&.tournament,
      last_tournament: events.joins(:tournament)
                            .order('tournaments.start_at DESC')
                            .first&.tournament
    }
  end
end 