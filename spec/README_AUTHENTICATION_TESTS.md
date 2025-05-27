# Tests de Autenticación con Devise

Este documento describe la suite completa de tests para las funcionalidades de autenticación implementadas con Devise en Smash Seeding Chile.

## 📋 Índice

- [Estructura de Tests](#estructura-de-tests)
- [Configuración](#configuración)
- [Factories](#factories)
- [Helpers](#helpers)
- [Tipos de Tests](#tipos-de-tests)
- [Ejecución](#ejecución)
- [Cobertura](#cobertura)

## 🏗️ Estructura de Tests

```
spec/
├── factories/
│   └── users.rb                    # Factory para usuarios con traits
├── support/
│   ├── devise_helpers.rb           # Helpers específicos de Devise
│   └── authentication_test_config.rb # Configuración para tests de auth
├── models/
│   └── user_spec.rb               # Tests del modelo User
├── requests/
│   └── devise/
│       ├── sessions_spec.rb       # Tests de login/logout
│       ├── registrations_spec.rb  # Tests de registro/edición
│       ├── passwords_spec.rb      # Tests de reset de contraseña
│       └── confirmations_spec.rb  # Tests de confirmación de email
├── system/
│   └── authentication_spec.rb     # Tests end-to-end
└── mailers/
    └── devise_mailer_spec.rb      # Tests de emails
```

## ⚙️ Configuración

### Dependencias

Los tests requieren las siguientes gemas (ya incluidas en el proyecto):

```ruby
# Gemfile
group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'capybara'
  gem 'shoulda-matchers'
  gem 'database_cleaner-active_record'
  gem 'webmock'
end
```

### Configuración de RSpec

Los tests están configurados en `spec/rails_helper.rb` con:

- FactoryBot para crear datos de prueba
- DatabaseCleaner para limpiar la base de datos
- Devise test helpers para autenticación
- Configuración de ActionMailer para tests

## 🏭 Factories

### Factory Principal

```ruby
# spec/factories/users.rb
factory :user do
  sequence(:email) { |n| "usuario#{n}@ejemplo.com" }
  password { "password123" }
  password_confirmation { "password123" }
  confirmed_at { Time.current }
  confirmation_sent_at { Time.current }
end
```

### Traits Disponibles

- `:unconfirmed` - Usuario sin confirmar email
- `:locked` - Usuario con cuenta bloqueada
- `:with_reset_password` - Usuario con token de reset activo
- `:with_remember_me` - Usuario con remember me activo

### Ejemplos de Uso

```ruby
# Usuario confirmado (por defecto)
user = create(:user)

# Usuario sin confirmar
unconfirmed_user = create(:user, :unconfirmed)

# Usuario bloqueado
locked_user = create(:user, :locked)

# Usuario con email específico
user = create(:user, email: 'test@example.com')
```

## 🛠️ Helpers

### DeviseHelpers

Métodos útiles para tests de autenticación:

```ruby
# Iniciar sesión en tests de request
sign_in_user(user)

# Cerrar sesión
sign_out_user

# Confirmar usuario
confirm_user(user)

# Bloquear usuario
lock_user(user)

# Generar token de reset
reset_password_for(user)
```

### AuthenticationTestHelpers

Helpers adicionales para casos específicos:

```ruby
# Crear usuario confirmado
create_confirmed_user(email: 'test@example.com')

# Crear usuario bloqueado
create_locked_user

# Simular intentos fallidos
simulate_failed_login_attempts(user, 3)

# Verificar envío de emails
expect_email_sent(to: user.email, subject_includes: 'confirmación')
```

## 🧪 Tipos de Tests

### 1. Tests de Modelo (`spec/models/user_spec.rb`)

Cubren:
- ✅ Validaciones de Devise
- ✅ Módulos incluidos
- ✅ Autenticación con contraseñas
- ✅ Confirmación de email
- ✅ Bloqueo de cuentas
- ✅ Reset de contraseñas
- ✅ Remember me
- ✅ Tracking de sesiones

### 2. Tests de Request (`spec/requests/devise/`)

#### Sessions (`sessions_spec.rb`)
- ✅ Mostrar página de login
- ✅ Login con credenciales válidas/inválidas
- ✅ Logout
- ✅ Remember me
- ✅ Bloqueo por intentos fallidos
- ✅ Redirecciones después del login

#### Registrations (`registrations_spec.rb`)
- ✅ Registro de nuevos usuarios
- ✅ Validaciones de registro
- ✅ Edición de perfil
- ✅ Cambio de email/contraseña
- ✅ Eliminación de cuenta
- ✅ Protección contra mass assignment

#### Passwords (`passwords_spec.rb`)
- ✅ Solicitud de reset de contraseña
- ✅ Cambio de contraseña con token
- ✅ Validación de tokens
- ✅ Expiración de tokens
- ✅ Seguridad (no reutilización)

#### Confirmations (`confirmations_spec.rb`)
- ✅ Confirmación de cuentas
- ✅ Reenvío de confirmaciones
- ✅ Reconfirmación de emails
- ✅ Validación de tokens
- ✅ Integración con login

### 3. Tests de Sistema (`spec/system/authentication_spec.rb`)

Tests end-to-end que simulan interacción real del usuario:
- ✅ Flujo completo de registro
- ✅ Flujo completo de login/logout
- ✅ Reset de contraseña completo
- ✅ Confirmación de email
- ✅ Edición de perfil
- ✅ Navegación con autenticación
- ✅ Bloqueo de cuentas

### 4. Tests de Mailers (`spec/mailers/devise_mailer_spec.rb`)

Verifican todos los emails de Devise:
- ✅ Email de confirmación
- ✅ Email de reset de contraseña
- ✅ Email de desbloqueo
- ✅ Email de cambio de email
- ✅ Email de cambio de contraseña
- ✅ Configuración y personalización

## 🚀 Ejecución

### Ejecutar Todos los Tests de Autenticación

```bash
# Todos los tests relacionados con autenticación
bundle exec rspec spec/models/user_spec.rb spec/requests/devise/ spec/system/authentication_spec.rb spec/mailers/devise_mailer_spec.rb

# Solo tests de modelo
bundle exec rspec spec/models/user_spec.rb

# Solo tests de request
bundle exec rspec spec/requests/devise/

# Solo tests de sistema
bundle exec rspec spec/system/authentication_spec.rb

# Solo tests de mailers
bundle exec rspec spec/mailers/devise_mailer_spec.rb
```

### Ejecutar Tests Específicos

```bash
# Solo tests de login
bundle exec rspec spec/requests/devise/sessions_spec.rb

# Solo tests de registro
bundle exec rspec spec/requests/devise/registrations_spec.rb

# Test específico
bundle exec rspec spec/requests/devise/sessions_spec.rb:25
```

### Con Opciones Útiles

```bash
# Con documentación detallada
bundle exec rspec --format documentation spec/requests/devise/

# Solo tests que fallan
bundle exec rspec --only-failures

# Con cobertura
bundle exec rspec --require spec_helper
```

## 📊 Cobertura

Los tests cubren:

### Funcionalidades de Devise
- ✅ **Database Authenticatable** - Login/logout con email y contraseña
- ✅ **Registerable** - Registro y edición de usuarios
- ✅ **Recoverable** - Reset de contraseñas
- ✅ **Rememberable** - Remember me
- ✅ **Validatable** - Validaciones de email y contraseña
- ✅ **Trackable** - Tracking de sesiones
- ✅ **Confirmable** - Confirmación de email
- ✅ **Lockable** - Bloqueo de cuentas

### Casos de Uso
- ✅ Registro exitoso y con errores
- ✅ Login exitoso y con errores
- ✅ Logout
- ✅ Reset de contraseña completo
- ✅ Confirmación de email
- ✅ Reconfirmación al cambiar email
- ✅ Edición de perfil
- ✅ Eliminación de cuenta
- ✅ Bloqueo por intentos fallidos
- ✅ Remember me
- ✅ Redirecciones apropiadas
- ✅ Envío de emails
- ✅ Validaciones de seguridad

### Casos Edge
- ✅ Tokens inválidos/expirados
- ✅ Usuarios ya confirmados
- ✅ Emails duplicados
- ✅ Contraseñas débiles
- ✅ Mass assignment protection
- ✅ Modo paranoico (no revelar si email existe)

## 🔧 Mantenimiento

### Agregar Nuevos Tests

1. **Para nuevas funcionalidades de autenticación:**
   ```ruby
   # En el archivo spec apropiado
   describe 'nueva funcionalidad' do
     it 'hace lo que debe hacer' do
       # test code
     end
   end
   ```

2. **Para nuevos traits en factories:**
   ```ruby
   # En spec/factories/users.rb
   trait :nuevo_trait do
     # configuración específica
   end
   ```

3. **Para nuevos helpers:**
   ```ruby
   # En spec/support/devise_helpers.rb
   def nuevo_helper
     # lógica del helper
   end
   ```

### Actualizar Tests

Cuando se modifiquen las funcionalidades de Devise:

1. Actualizar los tests correspondientes
2. Verificar que todos los tests pasen
3. Actualizar la documentación si es necesario

### Debugging

Para debuggear tests que fallan:

```ruby
# Agregar en el test
puts response.body # Para ver el HTML de respuesta
puts ActionMailer::Base.deliveries.last.body # Para ver emails
binding.pry # Para debugging interactivo
```

## 📝 Notas Importantes

1. **Configuración de Idioma:** Los tests están configurados para usar español (`I18n.locale = :es`)

2. **Limpieza de Emails:** Los emails se limpian automáticamente antes de cada test

3. **Bcrypt Optimizado:** En tests se usa `stretches = 1` para acelerar la encriptación

4. **Base de Datos:** Se usa DatabaseCleaner para mantener la base de datos limpia

5. **Tiempo:** Se incluyen helpers para manipular tiempo en tests (`travel`, `freeze_time`)

## 🤝 Contribuir

Para agregar nuevos tests:

1. Seguir las convenciones existentes
2. Usar los helpers disponibles
3. Agregar documentación para casos complejos
4. Verificar que todos los tests pasen
5. Actualizar este README si es necesario 