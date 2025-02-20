class Player < ApplicationRecord
  validates :user_id, uniqueness: true, allow_nil: true
  has_many :event_seeds
  has_many :tournaments, through: :event_seeds
end
