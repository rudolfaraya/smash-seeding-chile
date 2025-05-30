class UserPlayerRequestPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (record.user == user || user.admin?)
  end

  def new?
    user.present? && user.can_request_player_link?
  end

  def create?
    new?
  end

  def cancel?
    user.present? && record.user == user && record.can_be_modified?
  end

  def search_players?
    user.present?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end 