# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Creando usuarios por defecto..."

# Crear usuarios por defecto
default_users = [
  {
    email: "rudolfaraya@gmail.com",
    password: "beautyangelina",
    password_confirmation: "beautyangelina"
  },
  {
    email: "alonivanrivalvera@gmail.com", 
    password: "sakurai",
    password_confirmation: "sakurai"
  }
]

default_users.each do |user_attrs|
  user = User.find_or_initialize_by(email: user_attrs[:email])
  
  if user.new_record?
    user.assign_attributes(user_attrs)
    
    # Confirmar automáticamente el usuario para evitar problemas con emails
    user.confirmed_at = Time.current
    user.confirmation_sent_at = Time.current
    
    if user.save
      puts "✅ Usuario creado: #{user.email}"
    else
      puts "❌ Error creando usuario #{user_attrs[:email]}: #{user.errors.full_messages.join(', ')}"
    end
  else
    puts "ℹ️  Usuario ya existe: #{user.email}"
  end
end

puts "🎉 Seeds completados exitosamente!"
