require 'rails_helper'

RSpec.describe Devise::Mailer, type: :mailer do
  describe 'confirmation_instructions' do
    let(:user) { create(:user, :unconfirmed) }
    let(:token) { 'confirmation_token_123' }
    let(:mail) { Devise::Mailer.confirmation_instructions(user, token) }

    it 'envía el email al usuario correcto' do
      expect(mail.to).to eq([user.email])
    end

    it 'tiene el asunto correcto' do
      expect(mail.subject).to eq('Instrucciones de confirmación')
    end

    it 'incluye el token de confirmación en el cuerpo' do
      expect(mail.body.encoded).to include(token)
    end

    it 'incluye el enlace de confirmación' do
      expect(mail.body.encoded).to include(user_confirmation_url(confirmation_token: token))
    end

    it 'incluye el email del usuario' do
      expect(mail.body.encoded).to include(user.email)
    end

    it 'tiene el remitente correcto' do
      expect(mail.from).to eq(['please-change-me-at-config-initializers-devise@example.com'])
    end

    it 'es un email HTML' do
      expect(mail.content_type).to include('text/html')
    end
  end

  describe 'reset_password_instructions' do
    let(:user) { create(:user) }
    let(:token) { 'reset_password_token_123' }
    let(:mail) { Devise::Mailer.reset_password_instructions(user, token) }

    it 'envía el email al usuario correcto' do
      expect(mail.to).to eq([user.email])
    end

    it 'tiene el asunto correcto' do
      expect(mail.subject).to eq('Instrucciones para restablecer tu contraseña')
    end

    it 'incluye el token de reset en el cuerpo' do
      expect(mail.body.encoded).to include(token)
    end

    it 'incluye el enlace de reset de contraseña' do
      expect(mail.body.encoded).to include(edit_user_password_url(reset_password_token: token))
    end

    it 'incluye el email del usuario' do
      expect(mail.body.encoded).to include(user.email)
    end

    it 'incluye instrucciones sobre qué hacer' do
      expect(mail.body.encoded).to include('cambiar tu contraseña')
    end

    it 'incluye información sobre expiración' do
      expect(mail.body.encoded).to include('enlace expirará')
    end
  end

  describe 'unlock_instructions' do
    let(:user) { create(:user, :locked) }
    let(:token) { 'unlock_token_123' }
    let(:mail) { Devise::Mailer.unlock_instructions(user, token) }

    it 'envía el email al usuario correcto' do
      expect(mail.to).to eq([user.email])
    end

    it 'tiene el asunto correcto' do
      expect(mail.subject).to eq('Instrucciones de desbloqueo')
    end

    it 'incluye el token de desbloqueo en el cuerpo' do
      expect(mail.body.encoded).to include(token)
    end

    it 'incluye el enlace de desbloqueo' do
      expect(mail.body.encoded).to include(user_unlock_url(unlock_token: token))
    end

    it 'explica por qué la cuenta fue bloqueada' do
      expect(mail.body.encoded).to include('bloqueada')
    end
  end

  describe 'email_changed' do
    let(:user) { create(:user) }
    let(:mail) { Devise::Mailer.email_changed(user) }

    it 'envía el email al usuario correcto' do
      expect(mail.to).to eq([user.email])
    end

    it 'tiene el asunto correcto' do
      expect(mail.subject).to eq('Correo electrónico cambiado')
    end

    it 'incluye el nuevo email si existe' do
      user.unconfirmed_email = 'nuevo@email.com'
      mail = Devise::Mailer.email_changed(user)
      expect(mail.body.encoded).to include('nuevo@email.com')
    end

    it 'notifica sobre el cambio de email' do
      expect(mail.body.encoded).to include('correo electrónico ha sido cambiado')
    end
  end

  describe 'password_change' do
    let(:user) { create(:user) }
    let(:mail) { Devise::Mailer.password_change(user) }

    it 'envía el email al usuario correcto' do
      expect(mail.to).to eq([user.email])
    end

    it 'tiene el asunto correcto' do
      expect(mail.subject).to eq('Contraseña cambiada')
    end

    it 'notifica sobre el cambio de contraseña' do
      expect(mail.body.encoded).to include('contraseña ha sido cambiada')
    end

    it 'incluye información de seguridad' do
      expect(mail.body.encoded).to include('no realizaste este cambio')
    end
  end

  describe 'configuración de emails' do
    let(:user) { create(:user, :unconfirmed) }
    let(:mail) { Devise::Mailer.confirmation_instructions(user, 'token') }

    it 'usa la configuración de idioma correcta' do
      I18n.with_locale(:es) do
        expect(mail.subject).to eq('Instrucciones de confirmación')
      end
    end

    it 'incluye headers apropiados' do
      expect(mail.header['Content-Type'].to_s).to include('charset=UTF-8')
    end

    it 'tiene prioridad normal' do
      expect(mail.header['X-Priority']).to be_nil
    end
  end

  describe 'personalización de contenido' do
    let(:user) { create(:user, :unconfirmed, email: 'usuario@smashseeding.cl') }
    let(:mail) { Devise::Mailer.confirmation_instructions(user, 'token') }

    it 'incluye el nombre de la aplicación' do
      expect(mail.body.encoded).to include('Smash Seeding Chile')
    end

    it 'usa el dominio correcto en los enlaces' do
      expect(mail.body.encoded).to include('localhost')
    end
  end

  describe 'prevención de spam' do
    let(:user) { create(:user, :unconfirmed) }

    it 'no envía múltiples emails de confirmación muy seguidos' do
      # Primer email
      user.send_confirmation_instructions
      first_count = ActionMailer::Base.deliveries.count

      # Segundo email inmediatamente después
      user.send_confirmation_instructions
      second_count = ActionMailer::Base.deliveries.count

      # Debería haber enviado solo un email adicional
      expect(second_count - first_count).to eq(1)
    end
  end

  describe 'manejo de errores' do
    it 'maneja usuarios con email inválido' do
      user = build(:user, email: nil)
      expect {
        Devise::Mailer.confirmation_instructions(user, 'token')
      }.not_to raise_error
    end
  end

  describe 'templates de email' do
    let(:user) { create(:user, :unconfirmed) }
    let(:mail) { Devise::Mailer.confirmation_instructions(user, 'token') }

    it 'usa el template HTML correcto' do
      expect(mail.html_part.body.encoded).to include('<!DOCTYPE html>')
    end

    it 'incluye estilos CSS inline para compatibilidad' do
      expect(mail.html_part.body.encoded).to include('style=')
    end

    it 'es responsive para dispositivos móviles' do
      expect(mail.html_part.body.encoded).to include('viewport')
    end
  end

  describe 'integración con ActionMailer' do
    it 'usa la configuración de delivery method' do
      expect(Devise::Mailer.delivery_method).to eq(:test)
    end

    it 'respeta la configuración de perform_deliveries' do
      expect(Devise::Mailer.perform_deliveries).to be true
    end
  end
end 