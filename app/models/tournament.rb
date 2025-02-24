class Tournament < ApplicationRecord
  has_many :events, dependent: :destroy
  has_many :event_seeds, through: :events
  has_many :players, through: :event_seeds
end
