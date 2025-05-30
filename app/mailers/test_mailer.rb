class TestMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.test_mailer.welcome_email.subject
  #
  def welcome_email(email = 'test@example.com')
    @greeting = 'Hola desde Smash Seeding Chile!'
    @message = 'Este es un email de prueba para letter_opener.'

    mail(
      to: email,
      subject: '🎮 Email de prueba - Letter Opener funciona!'
    )
  end
end
