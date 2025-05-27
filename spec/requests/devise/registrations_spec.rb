require 'rails_helper'

RSpec.describe 'Devise::Registrations', type: :request do
  describe 'GET /users/sign_up' do
    it 'muestra la página de registro' do
      get new_user_registration_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Crear Cuenta')
    end

    it 'redirige si el usuario ya está autenticado' do
      user = create(:user)
      sign_in user
      get new_user_registration_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST /users' do
    let(:valid_params) do
      {
        user: {
          email: 'nuevo@usuario.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    context 'con parámetros válidos' do
      it 'crea un nuevo usuario' do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1)
      end

      it 'redirige después del registro exitoso' do
        post user_registration_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include('mensaje con un enlace de confirmación')
      end

      it 'crea un usuario no confirmado' do
        post user_registration_path, params: valid_params
        user = User.find_by(email: 'nuevo@usuario.com')
        expect(user.confirmed?).to be false
        expect(user.confirmation_token).to be_present
      end

      it 'envía email de confirmación' do
        expect {
          post user_registration_path, params: valid_params
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context 'con parámetros inválidos' do
      it 'no crea usuario con email inválido' do
        invalid_params = valid_params.deep_merge(
          user: { email: 'email_invalido' }
        )

        expect {
          post user_registration_path, params: invalid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no es válido')
      end

      it 'no crea usuario con contraseña muy corta' do
        invalid_params = valid_params.deep_merge(
          user: { password: '123', password_confirmation: '123' }
        )

        expect {
          post user_registration_path, params: invalid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('es demasiado corto')
      end

      it 'no crea usuario con contraseñas que no coinciden' do
        invalid_params = valid_params.deep_merge(
          user: { password_confirmation: 'different_password' }
        )

        expect {
          post user_registration_path, params: invalid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no coincide')
      end

      it 'no crea usuario con email duplicado' do
        create(:user, email: 'nuevo@usuario.com')

        expect {
          post user_registration_path, params: valid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('ya está en uso')
      end
    end
  end

  describe 'GET /users/edit' do
    let(:user) { create(:user) }

    context 'usuario autenticado' do
      before { sign_in user }

      it 'muestra la página de edición' do
        get edit_user_registration_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Editar Perfil')
      end
    end

    context 'usuario no autenticado' do
      it 'redirige al login' do
        get edit_user_registration_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'PATCH /users' do
    let(:user) { create(:user, password: 'old_password') }

    before { sign_in user }

    context 'actualizando email' do
      it 'actualiza el email exitosamente' do
        patch user_registration_path, params: {
          user: {
            email: 'nuevo@email.com',
            current_password: 'old_password'
          }
        }

        expect(response).to redirect_to(edit_user_registration_path)
        expect(flash[:notice]).to include('actualizada exitosamente')
        expect(user.reload.unconfirmed_email).to eq('nuevo@email.com')
      end

      it 'requiere confirmación para el nuevo email' do
        patch user_registration_path, params: {
          user: {
            email: 'nuevo@email.com',
            current_password: 'old_password'
          }
        }

        expect(user.reload.email).not_to eq('nuevo@email.com')
        expect(user.unconfirmed_email).to eq('nuevo@email.com')
      end
    end

    context 'actualizando contraseña' do
      it 'actualiza la contraseña exitosamente' do
        patch user_registration_path, params: {
          user: {
            password: 'new_password123',
            password_confirmation: 'new_password123',
            current_password: 'old_password'
          }
        }

        expect(response).to redirect_to(edit_user_registration_path)
        expect(flash[:notice]).to include('actualizada exitosamente')
        expect(user.reload.valid_password?('new_password123')).to be true
      end

      it 'requiere contraseña actual' do
        patch user_registration_path, params: {
          user: {
            password: 'new_password123',
            password_confirmation: 'new_password123',
            current_password: 'wrong_password'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('no es válido')
      end
    end

    context 'sin cambios' do
      it 'actualiza sin cambiar contraseña' do
        patch user_registration_path, params: {
          user: {
            email: user.email,
            current_password: 'old_password'
          }
        }

        expect(response).to redirect_to(edit_user_registration_path)
        expect(flash[:notice]).to include('actualizada exitosamente')
      end
    end
  end

  describe 'DELETE /users' do
    let(:user) { create(:user, password: 'password123') }

    before { sign_in user }

    it 'elimina la cuenta del usuario' do
      expect {
        delete user_registration_path
      }.to change(User, :count).by(-1)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include('cancelada exitosamente')
    end

    it 'cierra la sesión después de eliminar' do
      delete user_registration_path
      expect(session[:user_id]).to be_nil
    end
  end

  describe 'validaciones de seguridad' do
    it 'protege contra mass assignment' do
      post user_registration_path, params: {
        user: {
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          admin: true,
          confirmed_at: Time.current
        }
      }

      user = User.find_by(email: 'test@example.com')
      expect(user).to be_present
      expect(user.confirmed?).to be false
    end
  end
end 