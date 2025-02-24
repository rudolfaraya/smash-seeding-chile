class EventsController < ApplicationController
  before_action :set_tournament, only: [:index, :show, :seeds, :sync_seeds]
  before_action :set_event, only: [:show, :seeds, :sync_seeds]

  def index
    @events = @tournament.events
  end

  def show
  end

  def seeds
    @seeds = @event.event_seeds.order(seed_num: :asc)
  end

  def sync_seeds
    SyncEventSeeds.new(@event).call
    redirect_to tournament_event_seeds_path(@tournament, @event), notice: "Seeds y jugadores sincronizados exitosamente."
  rescue StandardError => e
    redirect_to tournament_event_seeds_path(@tournament, @event), alert: "Error al sincronizar: #{e.message}"
  end

  private

  def set_tournament
    @tournament = Tournament.find(params[:tournament_id])
  end

  def set_event
    @event = @tournament.events.find(params[:id])
  end
end
