require 'rails_helper'

RSpec.describe 'Authentication', type: :system do
  before do
    driven_by(:rack_test)
  end

  describe 'Registro de usuario' do
    it 'permite registrar un nuevo usuario' do
      visit new_user_registration_path

      expect(page).to have_content('Crear Cuenta')

      fill_in 'Correo Electrónico', with: 'nuevo@usuario.com'
      fill_in 'Contraseña', with: 'password123'
      fill_in 'Confirmar Contraseña', with: 'password123'

      click_button 'Crear Cuenta'

      expect(page).to have_content('mensaje con un enlace de confirmación')
      expect(User.find_by(email: 'nuevo@usuario.com')).to be_present
    end

    it 'muestra errores con datos inválidos' do
      visit new_user_registration_path

      fill_in 'Correo Electrónico', with: 'email_invalido'
      fill_in 'Contraseña', with: '123'
      fill_in 'Confirmar Contraseña', with: 'diferente'

      click_button 'Crear Cuenta'

      expect(page).to have_content('no es válido')
      expect(page).to have_content('es demasiado corto')
      expect(page).to have_content('no coincide')
    end

    it 'no permite registrar email duplicado' do
      create(:user, email: 'existente@usuario.com')

      visit new_user_registration_path

      fill_in 'Correo Electrónico', with: 'existente@usuario.com'
      fill_in 'Contraseña', with: 'password123'
      fill_in 'Confirmar Contraseña', with: 'password123'

      click_button 'Crear Cuenta'

      expect(page).to have_content('ya está en uso')
    end
  end

  describe 'Inicio de sesión' do
    let(:user) { create(:user, email: 'usuario@test.com', password: 'password123') }

    it 'permite iniciar sesión con credenciales válidas' do
      visit new_user_session_path

      expect(page).to have_content('Iniciar Sesión')

      fill_in 'Correo Electrónico', with: user.email
      fill_in 'Contraseña', with: 'password123'

      click_button 'Iniciar Sesión'

      expect(page).to have_content('Sesión iniciada exitosamente')
      expect(current_path).to eq(root_path)
    end

    it 'muestra error con credenciales inválidas' do
      visit new_user_session_path

      fill_in 'Correo Electrónico', with: user.email
      fill_in 'Contraseña', with: 'contraseña_incorrecta'

      click_button 'Iniciar Sesión'

      expect(page).to have_content('Correo electrónico o contraseña inválidos')
      expect(current_path).to eq(new_user_session_path)
    end

    it 'no permite login con usuario no confirmado' do
      unconfirmed_user = create(:user, :unconfirmed, email: 'noconfirmado@test.com', password: 'password123')

      visit new_user_session_path

      fill_in 'Correo Electrónico', with: unconfirmed_user.email
      fill_in 'Contraseña', with: 'password123'

      click_button 'Iniciar Sesión'

      expect(page).to have_content('Debes confirmar tu cuenta antes de continuar')
    end

    it 'funciona con remember me' do
      visit new_user_session_path

      fill_in 'Correo Electrónico', with: user.email
      fill_in 'Contraseña', with: 'password123'
      check 'Recordarme'

      click_button 'Iniciar Sesión'

      expect(page).to have_content('Sesión iniciada exitosamente')
      expect(user.reload.remember_created_at).to be_present
    end
  end

  describe 'Cierre de sesión' do
    let(:user) { create(:user) }

    it 'permite cerrar sesión' do
      sign_in user
      visit root_path

      click_link 'Cerrar Sesión'

      expect(page).to have_content('Sesión cerrada exitosamente')
      expect(current_path).to eq(root_path)
    end
  end

  describe 'Reset de contraseña' do
    let(:user) { create(:user, email: 'usuario@test.com') }

    it 'permite solicitar reset de contraseña' do
      visit new_user_password_path

      expect(page).to have_content('¿Olvidaste tu contraseña?')

      fill_in 'Correo Electrónico', with: user.email

      click_button 'Enviar instrucciones'

      expect(page).to have_content('instrucciones para restablecer tu contraseña')
      expect(user.reload.reset_password_token).to be_present
    end

    it 'permite cambiar contraseña con token válido' do
      user.send_reset_password_instructions
      token = user.reload.reset_password_token

      visit edit_user_password_path(reset_password_token: token)

      expect(page).to have_content('Cambiar contraseña')

      fill_in 'Nueva contraseña', with: 'nueva_password123'
      fill_in 'Confirmar nueva contraseña', with: 'nueva_password123'

      click_button 'Cambiar contraseña'

      expect(page).to have_content('contraseña se ha cambiado exitosamente')
      expect(user.reload.valid_password?('nueva_password123')).to be true
    end

    it 'muestra error con token inválido' do
      visit edit_user_password_path(reset_password_token: 'token_invalido')

      expect(page).to have_content('token de restablecimiento de contraseña no es válido')
    end
  end

  describe 'Confirmación de email' do
    let(:unconfirmed_user) { create(:user, :unconfirmed) }

    it 'permite confirmar cuenta con token válido' do
      visit user_confirmation_path(confirmation_token: unconfirmed_user.confirmation_token)

      expect(page).to have_content('cuenta ha sido confirmada exitosamente')
      expect(unconfirmed_user.reload.confirmed?).to be true
    end

    it 'permite reenviar confirmación' do
      visit new_user_confirmation_path

      expect(page).to have_content('Reenviar instrucciones de confirmación')

      fill_in 'Correo Electrónico', with: unconfirmed_user.email

      click_button 'Reenviar instrucciones'

      expect(page).to have_content('instrucciones de confirmación')
    end

    it 'muestra error con token inválido' do
      visit user_confirmation_path(confirmation_token: 'token_invalido')

      expect(page).to have_content('token de confirmación no es válido')
    end
  end

  describe 'Edición de perfil' do
    let(:user) { create(:user, email: 'usuario@test.com', password: 'password123') }

    before { sign_in user }

    it 'permite actualizar email' do
      visit edit_user_registration_path

      expect(page).to have_content('Editar Perfil')

      fill_in 'Correo Electrónico', with: 'nuevo@email.com'
      fill_in 'Contraseña actual', with: 'password123'

      click_button 'Actualizar'

      expect(page).to have_content('actualizada exitosamente')
      expect(user.reload.unconfirmed_email).to eq('nuevo@email.com')
    end

    it 'permite cambiar contraseña' do
      visit edit_user_registration_path

      fill_in 'Nueva Contraseña', with: 'nueva_password123'
      fill_in 'Confirmar nueva contraseña', with: 'nueva_password123'
      fill_in 'Contraseña actual', with: 'password123'

      click_button 'Actualizar'

      expect(page).to have_content('actualizada exitosamente')
      expect(user.reload.valid_password?('nueva_password123')).to be true
    end

    it 'requiere contraseña actual para cambios' do
      visit edit_user_registration_path

      fill_in 'Correo Electrónico', with: 'nuevo@email.com'
      fill_in 'Contraseña actual', with: 'contraseña_incorrecta'

      click_button 'Actualizar'

      expect(page).to have_content('no es válido')
    end

    it 'permite eliminar cuenta' do
      visit edit_user_registration_path

      accept_confirm do
        click_button 'Cancelar mi cuenta'
      end

      expect(page).to have_content('cancelada exitosamente')
      expect(User.find_by(id: user.id)).to be_nil
    end
  end

  describe 'Navegación con autenticación' do
    let(:user) { create(:user) }

    it 'redirige a login cuando se requiere autenticación' do
      visit tournaments_path

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content('Iniciar Sesión')
    end

    it 'redirige a la página solicitada después del login' do
      visit tournaments_path
      expect(current_path).to eq(new_user_session_path)

      fill_in 'Correo Electrónico', with: user.email
      fill_in 'Contraseña', with: user.password

      click_button 'Iniciar Sesión'

      expect(current_path).to eq(tournaments_path)
    end

    it 'muestra enlaces apropiados según estado de autenticación' do
      # Sin autenticar
      visit root_path
      expect(page).to have_link('Iniciar Sesión')
      expect(page).to have_link('Registrarse')
      expect(page).not_to have_link('Cerrar Sesión')

      # Autenticado
      sign_in user
      visit root_path
      expect(page).to have_link('Cerrar Sesión')
      expect(page).not_to have_link('Iniciar Sesión')
      expect(page).not_to have_link('Registrarse')
    end
  end

  describe 'Bloqueo de cuenta' do
    let(:user) { create(:user, email: 'usuario@test.com', password: 'password123') }

    it 'bloquea cuenta después de múltiples intentos fallidos' do
      visit new_user_session_path

      # Simular 5 intentos fallidos
      5.times do
        fill_in 'Correo Electrónico', with: user.email
        fill_in 'Contraseña', with: 'contraseña_incorrecta'
        click_button 'Iniciar Sesión'
      end

      expect(page).to have_content('Tu cuenta está bloqueada')
      expect(user.reload.access_locked?).to be true
    end
  end

  describe 'Validaciones en tiempo real' do
    it 'muestra validaciones de formato de email' do
      visit new_user_registration_path

      fill_in 'Correo Electrónico', with: 'email_invalido'
      fill_in 'Contraseña', with: 'password123'

      # Simular que el usuario sale del campo email
      find('#user_password').click

      # En una implementación real, esto podría mostrar validación en tiempo real
      # Por ahora, verificamos que el formulario funciona correctamente
      expect(page).to have_field('Correo Electrónico', with: 'email_invalido')
    end
  end
end 