class UserPlayerRequest < ApplicationRecord
  belongs_to :user
  belongs_to :player

  # Estados de la solicitud
  enum status: { 
    pending: 0, 
    approved: 1, 
    rejected: 2 
  }

  # Validaciones
  validates :user_id, presence: true
  validates :player_id, presence: true
  validates :message, presence: true, length: { maximum: 500 }
  
  # Un usuario solo puede tener una solicitud pendiente
  validates :user_id, uniqueness: { 
    conditions: -> { where(status: :pending) },
    message: "ya tiene una solicitud pendiente"
  }
  
  # Un player solo puede ser solicitado por un usuario a la vez (solo si está pendiente)
  validates :player_id, uniqueness: { 
    conditions: -> { where(status: :pending) },
    message: "ya tiene una solicitud pendiente de otro usuario"
  }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_admin_review, -> { pending.recent }

  # Callbacks
  before_validation :set_default_status, on: :create
  before_create :set_requested_at
  before_update :set_responded_at, if: :status_changed?

  # Métodos de instancia
  def approve!(admin_user, response_message = nil)
    transaction do
      update!(
        status: :approved,
        admin_response: response_message,
        responded_at: Time.current
      )
      
      # Vincular el player al usuario
      user.update!(player: player)
      
      Rails.logger.info "UserPlayerRequest #{id} aprobada por admin #{admin_user.id}"
    end
  end

  def reject!(admin_user, response_message)
    update!(
      status: :rejected,
      admin_response: response_message,
      responded_at: Time.current
    )
    
    Rails.logger.info "UserPlayerRequest #{id} rechazada por admin #{admin_user.id}"
  end

  def can_be_modified?
    pending?
  end

  def player_display_name
    player.entrant_name.presence || player.name.presence || "Player ##{player.id}"
  end

  def user_display_name
    user.display_name
  end

  private

  def set_requested_at
    self.requested_at = Time.current
  end

  def set_responded_at
    self.responded_at = Time.current if status_changed? && !pending?
  end

  def set_default_status
    self.status = :pending if status.blank?
  end
end
