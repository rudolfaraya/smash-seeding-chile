class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    true # Todos pueden ver índices por defecto
  end

  def show?
    true # Todos pueden ver registros individuales por defecto
  end

  def create?
    admin?
  end

  def new?
    create?
  end

  def update?
    admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  protected

  def admin?
    user&.admin?
  end

  def user_signed_in?
    user.present?
  end

  def owner?
    false # Por defecto no hay concepto de "dueño"
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end
end 