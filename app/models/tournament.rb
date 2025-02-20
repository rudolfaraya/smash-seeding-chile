class Tournament < ApplicationRecord
  validates :id, uniqueness: true
  has_many :event_seeds
  has_many :players, through: :event_seeds
end
