require 'rails_helper'

RSpec.describe 'Devise::Sessions', type: :request do
  describe 'GET /users/sign_in' do
    it 'muestra la página de login' do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Iniciar Sesión')
    end

    it 'redirige si el usuario ya está autenticado' do
      user = create(:user)
      sign_in user
      get new_user_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST /users/sign_in' do
    let(:user) { create(:user, password: 'password123') }

    context 'con credenciales válidas' do
      it 'inicia sesión exitosamente' do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'password123'
          }
        }

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Sesión iniciada exitosamente.')
      end

      it 'actualiza el tracking del usuario' do
        expect {
          post user_session_path, params: {
            user: {
              email: user.email,
              password: 'password123'
            }
          }
        }.to change { user.reload.sign_in_count }.by(1)
      end
    end

    context 'con credenciales inválidas' do
      it 'no inicia sesión con email incorrecto' do
        post user_session_path, params: {
          user: {
            email: 'wrong@email.com',
            password: 'password123'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Correo electrónico o contraseña inválidos')
      end

      it 'no inicia sesión con contraseña incorrecta' do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'wrong_password'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Correo electrónico o contraseña inválidos')
      end
    end

    context 'con usuario no confirmado' do
      let(:unconfirmed_user) { create(:user, :unconfirmed, password: 'password123') }

      it 'no permite iniciar sesión' do
        post user_session_path, params: {
          user: {
            email: unconfirmed_user.email,
            password: 'password123'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Debes confirmar tu cuenta antes de continuar')
      end
    end

    context 'con usuario bloqueado' do
      let(:locked_user) { create(:user, :locked, password: 'password123') }

      it 'no permite iniciar sesión' do
        post user_session_path, params: {
          user: {
            email: locked_user.email,
            password: 'password123'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Tu cuenta está bloqueada')
      end
    end

    context 'con remember me' do
      it 'establece remember me cuando está marcado' do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'password123',
            remember_me: '1'
          }
        }

        expect(response).to redirect_to(root_path)
        expect(user.reload.remember_created_at).to be_present
      end
    end
  end

  describe 'DELETE /users/sign_out' do
    let(:user) { create(:user) }

    context 'usuario autenticado' do
      before { sign_in user }

      it 'cierra sesión exitosamente' do
        delete destroy_user_session_path
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Sesión cerrada exitosamente.')
      end

      it 'limpia la sesión' do
        delete destroy_user_session_path
        expect(session[:user_id]).to be_nil
      end
    end

    context 'usuario no autenticado' do
      it 'redirige al login' do
        delete destroy_user_session_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'redirecciones después del login' do
    let(:user) { create(:user, password: 'password123') }

    it 'redirige a la página solicitada después del login' do
      get tournaments_path
      expect(response).to redirect_to(new_user_session_path)

      post user_session_path, params: {
        user: {
          email: user.email,
          password: 'password123'
        }
      }

      expect(response).to redirect_to(tournaments_path)
    end
  end

  describe 'límites de intentos de login' do
    let(:user) { create(:user, password: 'password123') }

    it 'bloquea la cuenta después de múltiples intentos fallidos' do
      # Simular múltiples intentos fallidos
      5.times do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: 'wrong_password'
          }
        }
      end

      user.reload
      expect(user.failed_attempts).to eq(5)
      expect(user.access_locked?).to be true
    end
  end
end 