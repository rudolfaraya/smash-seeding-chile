require 'rails_helper'

RSpec.describe 'Devise::Passwords', type: :request do
  describe 'GET /users/password/new' do
    it 'muestra la página de reset de contraseña' do
      get new_user_password_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('¿Olvidaste tu contraseña?')
    end

    it 'redirige si el usuario ya está autenticado' do
      user = create(:user)
      sign_in user
      get new_user_password_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST /users/password' do
    let(:user) { create(:user) }

    context 'con email válido' do
      it 'envía instrucciones de reset' do
        expect {
          post user_password_path, params: {
            user: { email: user.email }
          }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include('instrucciones para restablecer tu contraseña')
      end

      it 'genera token de reset' do
        post user_password_path, params: {
          user: { email: user.email }
        }

        user.reload
        expect(user.reset_password_token).to be_present
        expect(user.reset_password_sent_at).to be_present
      end

      it 'no revela si el email existe (modo paranoico)' do
        post user_password_path, params: {
          user: { email: 'noexiste@email.com' }
        }

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include('instrucciones para restablecer tu contraseña')
      end
    end

    context 'con email inválido' do
      it 'muestra error con email vacío' do
        post user_password_path, params: {
          user: { email: '' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no puede estar en blanco')
      end

      it 'muestra error con formato de email inválido' do
        post user_password_path, params: {
          user: { email: 'email_invalido' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no es válido')
      end
    end
  end

  describe 'GET /users/password/edit' do
    let(:user) { create(:user) }

    context 'con token válido' do
      before do
        user.send_reset_password_instructions
        user.reload
      end

      it 'muestra la página de cambio de contraseña' do
        get edit_user_password_path(reset_password_token: user.reset_password_token)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Cambiar contraseña')
      end
    end

    context 'con token inválido' do
      it 'redirige con token inexistente' do
        get edit_user_password_path(reset_password_token: 'token_invalido')
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include('token de restablecimiento de contraseña no es válido')
      end

      it 'redirige sin token' do
        get edit_user_password_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'con token expirado' do
      before do
        user.send_reset_password_instructions
        user.update!(reset_password_sent_at: 7.hours.ago)
      end

      it 'redirige con token expirado' do
        get edit_user_password_path(reset_password_token: user.reset_password_token)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include('token de restablecimiento de contraseña ha expirado')
      end
    end
  end

  describe 'PATCH /users/password' do
    let(:user) { create(:user, password: 'old_password') }

    before do
      user.send_reset_password_instructions
      user.reload
    end

    context 'con parámetros válidos' do
      let(:valid_params) do
        {
          user: {
            reset_password_token: user.reset_password_token,
            password: 'new_password123',
            password_confirmation: 'new_password123'
          }
        }
      end

      it 'actualiza la contraseña exitosamente' do
        patch user_password_path, params: valid_params

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include('contraseña se ha cambiado exitosamente')
        
        user.reload
        expect(user.valid_password?('new_password123')).to be true
      end

      it 'limpia el token de reset' do
        patch user_password_path, params: valid_params

        user.reload
        expect(user.reset_password_token).to be_nil
        expect(user.reset_password_sent_at).to be_nil
      end

      it 'inicia sesión automáticamente' do
        patch user_password_path, params: valid_params
        expect(controller.current_user).to eq(user)
      end
    end

    context 'con parámetros inválidos' do
      it 'no actualiza con contraseña muy corta' do
        patch user_password_path, params: {
          user: {
            reset_password_token: user.reset_password_token,
            password: '123',
            password_confirmation: '123'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('es demasiado corto')
        
        user.reload
        expect(user.valid_password?('old_password')).to be true
      end

      it 'no actualiza con contraseñas que no coinciden' do
        patch user_password_path, params: {
          user: {
            reset_password_token: user.reset_password_token,
            password: 'new_password123',
            password_confirmation: 'different_password'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no coincide')
      end

      it 'no actualiza con token inválido' do
        patch user_password_path, params: {
          user: {
            reset_password_token: 'token_invalido',
            password: 'new_password123',
            password_confirmation: 'new_password123'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no es válido')
      end

      it 'no actualiza con token expirado' do
        user.update!(reset_password_sent_at: 7.hours.ago)

        patch user_password_path, params: {
          user: {
            reset_password_token: user.reset_password_token,
            password: 'new_password123',
            password_confirmation: 'new_password123'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('ha expirado')
      end
    end
  end

  describe 'límites de tiempo' do
    let(:user) { create(:user) }

    it 'respeta el límite de 6 horas para reset' do
      user.send_reset_password_instructions
      
      # Simular que han pasado 7 horas
      travel 7.hours do
        patch user_password_path, params: {
          user: {
            reset_password_token: user.reset_password_token,
            password: 'new_password123',
            password_confirmation: 'new_password123'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('ha expirado')
      end
    end
  end

  describe 'seguridad' do
    let(:user) { create(:user) }

    it 'no permite reutilizar tokens de reset' do
      user.send_reset_password_instructions
      token = user.reset_password_token

      # Primer uso del token
      patch user_password_path, params: {
        user: {
          reset_password_token: token,
          password: 'new_password123',
          password_confirmation: 'new_password123'
        }
      }

      expect(response).to redirect_to(root_path)

      # Intentar reutilizar el mismo token
      patch user_password_path, params: {
        user: {
          reset_password_token: token,
          password: 'another_password123',
          password_confirmation: 'another_password123'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('no es válido')
    end
  end
end 