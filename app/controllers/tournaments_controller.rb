class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.order(start_at: :desc)
  end
end
