class Event < ApplicationRecord
  belongs_to :tournament
  has_many :event_seeds, dependent: :destroy
  has_many :players, through: :event_seeds
end
