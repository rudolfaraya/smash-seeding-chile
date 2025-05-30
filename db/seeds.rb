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

puts "🌱 Creando usuarios administradores..."

# Usuario admin principal
admin_user = User.find_or_create_by(email: "admin@smashseeding.cl") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = :admin
  user.confirmed_at = Time.current
end

if admin_user.persisted?
  puts "✅ Usuario admin creado: #{admin_user.email}"
else
  puts "❌ Error creando usuario admin: #{admin_user.errors.full_messages.join(', ')}"
end

# Usuario admin secundario (para tu cuenta de start.gg cuando la conectes)
# Este usuario se puede usar cuando conectes tu cuenta real de start.gg
secondary_admin = User.find_or_create_by(email: "rodo@smashseeding.cl") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = :admin
  user.confirmed_at = Time.current
end

if secondary_admin.persisted?
  puts "✅ Usuario admin secundario creado: #{secondary_admin.email}"
else
  puts "❌ Error creando usuario admin secundario: #{secondary_admin.errors.full_messages.join(', ')}"
end

puts "🌱 Seeds completados exitosamente!"
puts ""
puts "📋 Usuarios creados:"
puts "   Admin principal: admin@smashseeding.cl / password123"
puts "   Admin secundario: rodo@smashseeding.cl / password123"
puts ""
puts "🔐 Puedes usar estos usuarios para:"
puts "   - Probar funcionalidades de admin"
puts "   - Ejecutar sincronizaciones"
puts "   - Gestionar equipos y jugadores"
