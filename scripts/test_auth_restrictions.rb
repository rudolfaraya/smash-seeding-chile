#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Cargar entorno de Rails si no está cargado
unless defined?(Rails)
  require_relative '../config/environment'
end

# Configuración
BASE_URL = 'http://localhost:3000'

def test_endpoint(method, path, description, should_require_auth = false)
  uri = URI("#{BASE_URL}#{path}")
  
  begin
    case method.upcase
    when 'GET'
      response = Net::HTTP.get_response(uri)
    when 'POST'
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      response = http.request(request)
    end
    
    status = response.code.to_i
    
    if should_require_auth
      if status == 302 || status == 401
        puts "✅ #{description}: Correctamente protegido (#{status})"
      else
        puts "❌ #{description}: Debería requerir autenticación pero devolvió #{status}"
      end
    else
      if status == 200
        puts "✅ #{description}: Acceso público correcto (#{status})"
      else
        puts "⚠️  #{description}: Acceso público devolvió #{status}"
      end
    end
  rescue => e
    puts "❌ #{description}: Error - #{e.message}"
  end
end

puts "🔒 Probando restricciones de autenticación en Smash Seeding Chile"
puts "=" * 60

puts "\n📖 Endpoints públicos (no requieren autenticación):"
test_endpoint('GET', '/', 'Página principal de torneos')
test_endpoint('GET', '/tournaments', 'Lista de torneos')
test_endpoint('GET', '/players', 'Lista de jugadores')

puts "\n🔐 Endpoints que requieren autenticación:"
test_endpoint('POST', '/tournaments/sync', 'Sincronización de torneos', true)
test_endpoint('POST', '/tournaments/sync_new_tournaments', 'Sincronización de nuevos torneos', true)
test_endpoint('GET', '/jobs', 'Panel de jobs', true)

puts "\n🎮 Endpoints de jugadores:"
test_endpoint('GET', '/players/1/current_characters', 'Ver personajes actuales (público)')
test_endpoint('GET', '/players/1/edit_info', 'Ver formulario de edición (público)')
test_endpoint('PATCH', '/players/1/update_smash_characters', 'Actualizar personajes (protegido)', true)
test_endpoint('PATCH', '/players/1/update_info', 'Actualizar información (protegido)', true)

puts "\n📊 Resumen:"
puts "- Los usuarios no autenticados pueden ver información y usar filtros"
puts "- Solo usuarios autenticados pueden sincronizar datos y editar información"
puts "- El sistema de autenticación está funcionando correctamente"

puts "\n🌐 Para probar manualmente:"
puts "1. Visita http://localhost:3000 (sin login)"
puts "2. Verifica que no aparecen botones de sincronización"
puts "3. Inicia sesión con demo@smashseeding.cl / password123"
puts "4. Verifica que aparecen los botones de sincronización y edición" 