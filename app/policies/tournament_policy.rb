class TournamentPolicy < ApplicationPolicy
  def index?
    true # Todos pueden ver torneos
  end

  def show?
    true # Todos pueden ver torneos individuales
  end

  def create?
    admin? # Solo admins pueden crear torneos manualmente
  end

  def update?
    admin? # Solo admins pueden editar torneos
  end

  def destroy?
    admin? # Solo admins pueden eliminar torneos
  end

  # Métodos específicos para sincronización
  def sync?
    admin?
  end

  def sync_new_tournaments?
    admin?
  end

  def sync_latest_tournaments?
    admin?
  end

  def sync_events?
    admin?
  end

  class Scope < Scope
    def resolve
      scope.all # Todos pueden ver todos los torneos
    end
  end
end 