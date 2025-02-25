class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.order(start_at: :desc).includes(events: :event_seeds)
  end
end
