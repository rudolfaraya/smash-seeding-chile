class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable, 
         :confirmable
  
  # Relaciones
  belongs_to :player, optional: true
  has_many :user_player_requests, dependent: :destroy
  
  # Enums
  enum role: { user: 0, admin: 1 }
  
  # Validaciones
  validates :startgg_id, uniqueness: true, allow_nil: true
  validates :startgg_username, presence: true, if: :startgg_id?
  
  # Métodos de clase
  def self.from_omniauth(auth)
    user_data = auth.info
    startgg_id = user_data[:id]
    
    user = find_by(startgg_id: startgg_id)
    
    if user
      # Usuario existente - actualizar datos si es necesario
      user.update(
        startgg_username: user_data[:gamer_tag],
        email: user_data[:email] || user.email
      )
      user
    else
      # Nuevo usuario desde start.gg
      create!(
        email: user_data[:email] || "#{startgg_id}@startgg.temp",
        startgg_id: startgg_id,
        startgg_username: user_data[:gamer_tag] || "Player#{startgg_id}",
        role: :user,
        password: Devise.friendly_token[0, 20],
        confirmed_at: Time.current # Auto-confirmar usuarios OAuth
      )
    end
  end
  
  # Métodos de instancia
  def admin?
    role == 'admin'
  end
  
  def display_name
    startgg_username.presence || email.split('@').first
  end
  
  def from_startgg?
    startgg_id.present?
  end
  
  def can_edit_player?(player_to_edit)
    admin? || (player.present? && player == player_to_edit)
  end

  # Métodos para gestión de solicitudes de player
  def has_pending_player_request?
    user_player_requests.pending.exists?
  end

  def pending_player_request
    user_player_requests.pending.first
  end

  def can_request_player_link?
    player.nil? && !has_pending_player_request?
  end

  def has_linked_player?
    player.present?
  end

  def needs_player_setup?
    # Usuario necesita configurar player si no es admin, no tiene player linkeado y no tiene solicitud pendiente
    !admin? && !has_linked_player? && !has_pending_player_request?
  end

  def last_player_request
    user_player_requests.recent.first
  end

  def player_request_status
    return nil unless last_player_request
    last_player_request.status
  end
end
