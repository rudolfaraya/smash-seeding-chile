require 'rails_helper'

RSpec.describe 'Devise::Confirmations', type: :request do
  describe 'GET /users/confirmation/new' do
    it 'muestra la página de reenvío de confirmación' do
      get new_user_confirmation_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Reenviar instrucciones de confirmación')
    end

    it 'redirige si el usuario ya está autenticado' do
      user = create(:user)
      sign_in user
      get new_user_confirmation_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST /users/confirmation' do
    let(:unconfirmed_user) { create(:user, :unconfirmed) }

    context 'con email válido' do
      it 'reenvía instrucciones de confirmación' do
        expect {
          post user_confirmation_path, params: {
            user: { email: unconfirmed_user.email }
          }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include('instrucciones de confirmación')
      end

      it 'genera nuevo token de confirmación' do
        old_token = unconfirmed_user.confirmation_token
        
        post user_confirmation_path, params: {
          user: { email: unconfirmed_user.email }
        }

        unconfirmed_user.reload
        expect(unconfirmed_user.confirmation_token).to be_present
        expect(unconfirmed_user.confirmation_token).not_to eq(old_token)
      end

      it 'no reenvía si el usuario ya está confirmado' do
        confirmed_user = create(:user)
        
        expect {
          post user_confirmation_path, params: {
            user: { email: confirmed_user.email }
          }
        }.not_to change { ActionMailer::Base.deliveries.count }

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include('instrucciones de confirmación')
      end
    end

    context 'con email inválido' do
      it 'muestra error con email vacío' do
        post user_confirmation_path, params: {
          user: { email: '' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no puede estar en blanco')
      end

      it 'muestra error con formato de email inválido' do
        post user_confirmation_path, params: {
          user: { email: 'email_invalido' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no es válido')
      end

      it 'no revela si el email existe (modo paranoico)' do
        post user_confirmation_path, params: {
          user: { email: 'noexiste@email.com' }
        }

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include('instrucciones de confirmación')
      end
    end
  end

  describe 'GET /users/confirmation' do
    let(:unconfirmed_user) { create(:user, :unconfirmed) }

    context 'con token válido' do
      it 'confirma la cuenta exitosamente' do
        get user_confirmation_path(confirmation_token: unconfirmed_user.confirmation_token)

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include('cuenta ha sido confirmada exitosamente')
        
        unconfirmed_user.reload
        expect(unconfirmed_user.confirmed?).to be true
        expect(unconfirmed_user.confirmation_token).to be_nil
      end

      it 'establece confirmed_at' do
        expect {
          get user_confirmation_path(confirmation_token: unconfirmed_user.confirmation_token)
        }.to change { unconfirmed_user.reload.confirmed_at }.from(nil)
      end

      it 'inicia sesión automáticamente después de confirmar' do
        get user_confirmation_path(confirmation_token: unconfirmed_user.confirmation_token)
        expect(controller.current_user).to eq(unconfirmed_user)
      end
    end

    context 'con token inválido' do
      it 'muestra error con token inexistente' do
        get user_confirmation_path(confirmation_token: 'token_invalido')

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include('token de confirmación no es válido')
      end

      it 'muestra error sin token' do
        get user_confirmation_path

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include('token de confirmación no es válido')
      end
    end

    context 'con usuario ya confirmado' do
      let(:confirmed_user) { create(:user) }

      it 'muestra error si ya está confirmado' do
        get user_confirmation_path(confirmation_token: 'cualquier_token')

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include('ya fue confirmado')
      end
    end
  end

  describe 'confirmación durante el registro' do
    it 'envía email de confirmación al registrarse' do
      expect {
        post user_registration_path, params: {
          user: {
            email: 'nuevo@usuario.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      user = User.find_by(email: 'nuevo@usuario.com')
      expect(user.confirmed?).to be false
      expect(user.confirmation_token).to be_present
    end
  end

  describe 'reconfirmación de email' do
    let(:user) { create(:user, password: 'password123') }

    before { sign_in user }

    it 'requiere confirmación al cambiar email' do
      patch user_registration_path, params: {
        user: {
          email: 'nuevo@email.com',
          current_password: 'password123'
        }
      }

      user.reload
      expect(user.email).not_to eq('nuevo@email.com')
      expect(user.unconfirmed_email).to eq('nuevo@email.com')
      expect(user.confirmation_token).to be_present
    end

    it 'envía email de confirmación para el nuevo email' do
      expect {
        patch user_registration_path, params: {
          user: {
            email: 'nuevo@email.com',
            current_password: 'password123'
          }
        }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'confirma el nuevo email con token válido' do
      patch user_registration_path, params: {
        user: {
          email: 'nuevo@email.com',
          current_password: 'password123'
        }
      }

      user.reload
      get user_confirmation_path(confirmation_token: user.confirmation_token)

      user.reload
      expect(user.email).to eq('nuevo@email.com')
      expect(user.unconfirmed_email).to be_nil
    end
  end

  describe 'límites de tiempo' do
    let(:unconfirmed_user) { create(:user, :unconfirmed) }

    it 'permite confirmación sin límite de tiempo por defecto' do
      # Simular que han pasado muchos días
      travel 30.days do
        get user_confirmation_path(confirmation_token: unconfirmed_user.confirmation_token)

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include('cuenta ha sido confirmada exitosamente')
      end
    end
  end

  describe 'seguridad' do
    let(:unconfirmed_user) { create(:user, :unconfirmed) }

    it 'no permite reutilizar tokens de confirmación' do
      token = unconfirmed_user.confirmation_token

      # Primera confirmación
      get user_confirmation_path(confirmation_token: token)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to include('confirmada exitosamente')

      # Intentar reutilizar el mismo token
      get user_confirmation_path(confirmation_token: token)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to include('ya fue confirmado')
    end

    it 'genera tokens únicos para cada usuario' do
      user1 = create(:user, :unconfirmed)
      user2 = create(:user, :unconfirmed)

      expect(user1.confirmation_token).not_to eq(user2.confirmation_token)
    end
  end

  describe 'integración con login' do
    let(:unconfirmed_user) { create(:user, :unconfirmed, password: 'password123') }

    it 'no permite login sin confirmación' do
      post user_session_path, params: {
        user: {
          email: unconfirmed_user.email,
          password: 'password123'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Debes confirmar tu cuenta antes de continuar')
    end

    it 'permite login después de confirmar' do
      get user_confirmation_path(confirmation_token: unconfirmed_user.confirmation_token)

      post user_session_path, params: {
        user: {
          email: unconfirmed_user.email,
          password: 'password123'
        }
      }

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Sesión iniciada exitosamente.')
    end
  end
end 