class PlayerPolicy < ApplicationPolicy
  def index?
    true # Todos pueden ver la lista de jugadores
  end

  def show?
    true # Todos pueden ver perfiles individuales
  end

  def create?
    admin? # Solo admins pueden crear jugadores manualmente
  end

  def update?
    admin? || owner?
  end

  def edit?
    update?
  end

  def destroy?
    admin? # Solo admins pueden eliminar jugadores
  end

  # Métodos específicos para Player
  def update_smash_characters?
    admin? || owner?
  end

  def update_info?
    admin? || owner?
  end

  def edit_info?
    admin? || owner?
  end

  def current_characters?
    admin? || owner?
  end

  def edit_teams?
    admin? || owner?
  end

  def update_teams?
    admin? || owner?
  end

  protected

  def owner?
    user_signed_in? && user.player == record
  end

  class Scope < Scope
    def resolve
      scope.all # Todos pueden ver todos los jugadores
    end
  end
end 