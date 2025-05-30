class EmailTestController < ApplicationController
  def send_test
    # Enviar el email de prueba
    TestMailer.welcome_email('test@example.com').deliver_now
    
    redirect_to email_test_send_test_path, notice: '📧 ¡Email enviado! Debería abrirse automáticamente en tu navegador.'
  rescue => e
    redirect_to email_test_send_test_path, alert: "Error enviando email: #{e.message}"
  end
end
