class EventSeed < ApplicationRecord
  belongs_to :tournament
  belongs_to :player

  validates :event_id, :seed_num, presence: true
end
