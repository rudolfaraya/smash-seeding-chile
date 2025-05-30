class TeamPolicy < ApplicationPolicy
  def index?
    true # Todos pueden ver equipos
  end

  def show?
    true # Todos pueden ver equipos individuales
  end

  def create?
    admin? # Solo admins pueden crear equipos
  end

  def update?
    admin? # Solo admins pueden editar equipos
  end

  def destroy?
    admin? # Solo admins pueden eliminar equipos
  end

  # Métodos específicos para gestión de jugadores en equipos
  def add_player?
    admin?
  end

  def remove_player?
    admin?
  end

  def search_players?
    admin? # Solo admins pueden buscar jugadores para agregar a equipos
  end

  class Scope < Scope
    def resolve
      scope.all # Todos pueden ver todos los equipos
    end
  end
end 