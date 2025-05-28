class PlayerTeam < ApplicationRecord
  belongs_to :player
  belongs_to :team

  validates :player_id, uniqueness: { scope: :team_id }
  validate :only_one_primary_team_per_player, if: :is_primary?

  before_save :unset_other_primary_teams, if: :is_primary?

  scope :primary, -> { where(is_primary: true) }
  scope :secondary, -> { where(is_primary: false) }

  private

  def only_one_primary_team_per_player
    existing_primary = PlayerTeam.where(player: player, is_primary: true)
    existing_primary = existing_primary.where.not(id: id) if persisted?
    
    if existing_primary.exists?
      errors.add(:is_primary, "el jugador ya tiene un equipo principal")
    end
  end

  def unset_other_primary_teams
    PlayerTeam.where(player: player, is_primary: true)
              .where.not(id: id)
              .update_all(is_primary: false)
  end
end
