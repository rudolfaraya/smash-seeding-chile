class EventPolicy < ApplicationPolicy
  def index?
    true # Todos pueden ver eventos
  end

  def show?
    true # Todos pueden ver eventos individuales
  end

  def seeds?
    true # Todos pueden ver seeds
  end

  def create?
    admin? # Solo admins pueden crear eventos manualmente
  end

  def update?
    admin? # Solo admins pueden editar eventos
  end

  def destroy?
    admin? # Solo admins pueden eliminar eventos
  end

  # Métodos específicos para sincronización de seeds
  def sync_seeds?
    admin?
  end

  class Scope < Scope
    def resolve
      scope.all # Todos pueden ver todos los eventos
    end
  end
end 