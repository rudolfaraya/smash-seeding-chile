require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validaciones' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }

    it 'valida formato de email' do
      user = build(:user, email: 'email_invalido')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'acepta emails válidos' do
      valid_emails = %w[
        test@example.com
        user.name@domain.co.uk
        user+tag@example.org
      ]

      valid_emails.each do |email|
        user = build(:user, email: email)
        expect(user).to be_valid, "#{email} debería ser válido"
      end
    end
  end

  describe 'módulos de Devise' do
    it 'incluye database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'incluye registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'incluye recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'incluye rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'incluye validatable' do
      expect(User.devise_modules).to include(:validatable)
    end

    it 'incluye trackable' do
      expect(User.devise_modules).to include(:trackable)
    end

    it 'incluye confirmable' do
      expect(User.devise_modules).to include(:confirmable)
    end
  end

  describe 'autenticación' do
    let(:user) { create(:user, password: 'password123') }

    it 'autentica con credenciales correctas' do
      expect(user.valid_password?('password123')).to be true
    end

    it 'no autentica con contraseña incorrecta' do
      expect(user.valid_password?('wrong_password')).to be false
    end

    it 'encripta la contraseña' do
      expect(user.encrypted_password).to be_present
      expect(user.encrypted_password).not_to eq('password123')
    end
  end

  describe 'confirmación de email' do
    context 'usuario confirmado' do
      let(:user) { create(:user) }

      it 'está confirmado' do
        expect(user.confirmed?).to be true
      end

      it 'tiene confirmed_at establecido' do
        expect(user.confirmed_at).to be_present
      end
    end

    context 'usuario no confirmado' do
      let(:user) { create(:user, :unconfirmed) }

      it 'no está confirmado' do
        expect(user.confirmed?).to be false
      end

      it 'no tiene confirmed_at establecido' do
        expect(user.confirmed_at).to be_nil
      end

      it 'puede ser confirmado' do
        user.confirm
        expect(user.confirmed?).to be true
      end
    end
  end

  describe 'bloqueo de cuenta' do
    # Nota: El módulo :lockable no está habilitado en este proyecto
    # Estos tests están comentados hasta que se habilite
    
    context 'usuario normal' do
      let(:user) { create(:user) }

      it 'no tiene funcionalidad de bloqueo habilitada' do
        expect(user).not_to respond_to(:access_locked?)
        expect(user).not_to respond_to(:unlock_access!)
      end
    end
  end

  describe 'reset de contraseña' do
    let(:user) { create(:user) }

    it 'puede generar token de reset' do
      user.send_reset_password_instructions
      expect(user.reset_password_token).to be_present
      expect(user.reset_password_sent_at).to be_present
    end

    it 'puede resetear contraseña con token válido' do
      token = user.send_reset_password_instructions
      user.reset_password('new_password123', 'new_password123')
      expect(user.valid_password?('new_password123')).to be true
    end
  end

  describe 'remember me' do
    let(:user) { create(:user) }

    it 'puede ser recordado' do
      user.remember_me!
      expect(user.remember_created_at).to be_present
    end

    it 'puede olvidar remember me' do
      user.remember_me!
      user.forget_me!
      expect(user.remember_created_at).to be_nil
    end
  end

  describe 'tracking' do
    let(:user) { create(:user) }

    it 'actualiza información de sign in' do
      expect {
        user.update_tracked_fields!(request_mock)
      }.to change { user.sign_in_count }.by(1)
    end

    private

    def request_mock
      double('request', remote_ip: '127.0.0.1')
    end
  end

  describe 'factory' do
    it 'crea un usuario válido' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'crea un usuario no confirmado' do
      user = build(:user, :unconfirmed)
      expect(user.confirmed?).to be false
    end

    # Test comentado porque :lockable no está habilitado
    # it 'crea un usuario bloqueado' do
    #   user = build(:user, :locked)
    #   expect(user.locked_at).to be_present
    # end

    it 'crea un usuario con reset de contraseña' do
      user = build(:user, :with_reset_password)
      expect(user.reset_password_token).to be_present
    end

    it 'crea un usuario con remember me' do
      user = build(:user, :with_remember_me)
      expect(user.remember_created_at).to be_present
    end
  end
end
