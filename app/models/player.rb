class Player < ApplicationRecord
  has_many :event_seeds, dependent: :destroy
  has_many :events, through: :event_seeds
  has_many :tournaments, through: :events
end
