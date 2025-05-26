# 🎮 Smash Seeding Chile

**Sistema de gestión y sincronización de torneos de Super Smash Bros. Ultimate en Chile**

[![Ruby](https://img.shields.io/badge/Ruby-3.3.2-red.svg)](https://www.ruby-lang.org/en/)
[![Rails](https://img.shields.io/badge/Rails-8.0-red.svg)](https://rubyonrails.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 📋 Descripción

Smash Seeding Chile es una aplicación web desarrollada en Ruby on Rails que permite la gestión centralizada y sincronización automática de torneos de Super Smash Bros. Ultimate desde la API de Start.gg. El sistema facilita el seguimiento de jugadores, eventos, rankings y ubicaciones de torneos en todo Chile.

## ✨ Funcionalidades Principales

### 🏆 Gestión de Torneos
- **Sincronización automática** desde Start.gg API
- **Detección inteligente de torneos online** basada en palabras clave
- **Marcado automático** de torneos con `venue_address: "Chile"` como online
- **Parseo de ubicaciones** con detección de ciudad y región chilena
- **Filtrado avanzado** por región, ciudad, fecha y estado de sincronización

### 👤 Sistema de Jugadores
- **Base de datos completa** de jugadores chilenos de Smash
- **Sincronización de perfiles** desde Start.gg
- **Búsqueda y filtrado** de jugadores
- **Estadísticas de participación**
- **Gestión de personajes** con iconos y skins

### 🎯 Eventos y Seeds
- **Gestión de eventos** por torneo (Singles, Doubles, etc.)
- **Sincronización de seeds** y brackets
- **Seguimiento del estado** de sincronización
- **Visualización detallada** de participantes por evento
- **Orden personalizable** de columnas en tablas de seeds

### 🔧 Herramientas Administrativas
- **Comandos rake especializados** para mantenimiento
- **Sincronización masiva** con control de rate limits
- **Pluralización en español** para interfaz localizada

## 🛠️ Tecnologías Utilizadas

### Backend
- **Ruby 3.3.2** - Lenguaje de programación
- **Rails 8.0** - Framework web
- **SQLite3** - Base de datos (desarrollo)
- **Puma** - Servidor web

### Frontend
- **Hotwire (Turbo + Stimulus)** - Interactividad SPA-like
- **Tailwind CSS 4** - Framework CSS para diseño responsive
- **Importmap** - Gestión de módulos JavaScript

### APIs y Servicios
- **HTTParty** - Cliente HTTP para APIs
- **Faraday** - Adaptador HTTP avanzado
- **Start.gg API** - Fuente de datos de torneos
- **SSBWiki** - Información adicional de personajes

### Utilidades
- **Kaminari** - Paginación
- **Nokogiri** - Web scraping
- **Bootsnap** - Optimización de arranque
- **Dotenv** - Gestión de variables de entorno

## 📦 Instalación y Configuración

### Prerrequisitos
- Ruby 3.3.2
- Node.js 18+ (para assets)
- SQLite3
- Git

### 🚀 Guía de Instalación Paso a Paso

#### 1. **Clonar el repositorio**
```bash
git clone https://github.com/tu-usuario/smash-seeding-chile.git
cd smash-seeding-chile
```

#### 2. **Instalar dependencias de Ruby**
```bash
# Instalar bundler si no lo tienes
gem install bundler

# Instalar gemas del proyecto
bundle install
```

#### 3. **Configurar variables de entorno**
```bash
# Copiar archivo de ejemplo
cp .env.example .env

# Editar .env con tu token de Start.gg API
# Obtén tu token en: https://start.gg/admin/profile/developer
```

**Contenido del archivo `.env`:**
```bash
START_GG_API_TOKEN=tu_token_de_start_gg_aqui
RAILS_ENV=development
DATABASE_URL=sqlite3:db/development.sqlite3
```

#### 4. **Configurar base de datos**
```bash
# Crear base de datos
bin/rails db:create

# Ejecutar migraciones
bin/rails db:migrate

# Cargar datos iniciales (opcional)
bin/rails db:seed
```

#### 5. **Instalar dependencias de JavaScript**
```bash
# Si usas npm
npm install

# O si usas yarn
yarn install
```

#### 6. **Compilar assets (si es necesario)**
```bash
bin/rails assets:precompile
```

#### 7. **Levantar el servidor**
```bash
# Opción 1: Con hot-reload para desarrollo
bin/dev

# Opción 2: Solo el servidor Rails
bin/rails server

# Opción 3: En modo producción
RAILS_ENV=production bin/rails server
```

La aplicación estará disponible en `http://localhost:3000`

## 📊 Guía de Sincronización de Datos

### 🔄 Orden Recomendado para Traer los Datos

#### **Paso 1: Sincronización Inicial de Torneos**
```bash
# Sincronizar datos básicos de Smash Ultimate desde Start.gg
bin/rails smash:sync

# O sincronizar todos los torneos faltantes (con límite)
bin/rails tournaments:sync_all_missing[50]
```

#### **Paso 2: Procesar Ubicaciones**
```bash
# Parsear ubicaciones de todos los torneos
bin/rails tournaments:parse_locations

# Detectar torneos online automáticamente
bin/rails tournaments:detect_online_tournaments

# Marcar torneos con venue_address "Chile" como online
bin/rails tournaments:mark_chile_as_online
```

#### **Paso 3: Sincronizar Eventos**
```bash
# Sincronizar eventos para todos los torneos
bin/rails tournaments:sync_all_events

# O sincronizar eventos de un torneo específico
bin/rails tournament:sync_complete[tournament_id]
```

#### **Paso 4: Sincronizar Seeds y Jugadores**
```bash
# Sincronizar seeds de todos los eventos
bin/rails events:sync_all_seeds

# O sincronizar seeds de un evento específico
bin/rails event:sync_seeds[event_id]
```

#### **Paso 5: Verificación y Limpieza**
```bash
# Verificar estado de sincronización
bin/rails tournaments:list_missing

# Mostrar estadísticas
bin/rails tournaments:location_stats

# Verificar URLs de Start.gg
bin/rails tournaments:check_start_gg_urls
```

## 🚀 Comandos Rake Disponibles

### 📥 Sincronización de Torneos
```bash
# Sincronizar datos de Smash Ultimate desde Start.gg
bin/rails smash:sync

# Sincronizar todos los torneos faltantes (respeta rate limits)
bin/rails tournaments:sync_all_missing[limit]
# Ejemplo: bin/rails tournaments:sync_all_missing[100]

# Sincronizar torneo específico con todos sus datos
bin/rails tournament:sync_complete[tournament_id]
# Ejemplo: bin/rails tournament:sync_complete[123456]

# Sincronizar solo eventos nuevos
bin/rails tournaments:sync_new_tournaments

# Sincronizar eventos de todos los torneos
bin/rails tournaments:sync_all_events

# Sincronizar seeds de todos los eventos
bin/rails events:sync_all_seeds

# Sincronizar seeds de un evento específico
bin/rails event:sync_seeds[event_id]
```

### 🗺️ Gestión de Ubicaciones
```bash
# Parsear ubicaciones de todos los torneos
bin/rails tournaments:parse_locations

# Reparsear ubicaciones específicas (IDs separados por comas)
bin/rails tournaments:reparse_locations[tournament_ids]
# Ejemplo: bin/rails tournaments:reparse_locations[123,456,789]

# Detectar torneos online automáticamente
bin/rails tournaments:detect_online_tournaments

# Marcar torneos con venue_address "Chile" como online
bin/rails tournaments:mark_chile_as_online

# Mostrar estadísticas de ubicaciones
bin/rails tournaments:location_stats

# Revisar torneos que podrían ser online
bin/rails tournaments:check_potential_online
```

### 📊 Información y Estadísticas
```bash
# Mostrar información detallada de un torneo
bin/rails tournament:info[tournament_id]
# Ejemplo: bin/rails tournament:info[123456]

# Buscar torneo por nombre
bin/rails tournament:search[query]
# Ejemplo: bin/rails tournament:search["Smash Factor"]

# Listar torneos que necesitan sincronización
bin/rails tournaments:list_missing

# Verificar URLs de Start.gg
bin/rails tournaments:check_start_gg_urls

# Mostrar torneos con venue_address "Chile"
bin/rails tournaments:show_chile_tournaments

# Mostrar estadísticas generales del sistema
bin/rails system:stats
```

### 👥 Gestión de Jugadores
```bash
# Sincronizar información de todos los jugadores
bin/rails players:sync_all

# Sincronizar jugador específico
bin/rails player:sync[player_id]

# Actualizar estadísticas de jugadores
bin/rails players:update_stats

# Limpiar jugadores duplicados
bin/rails players:clean_duplicates
```

### 🎮 Gestión de Personajes
```bash
# Sincronizar iconos de personajes desde SSBWiki
bin/rails characters:sync_icons

# Actualizar información de personajes
bin/rails characters:update_info

# Verificar integridad de assets de personajes
bin/rails characters:check_assets
```

### 🔧 Mantenimiento del Sistema
```bash
# Limpiar logs antiguos
bin/rails log:clear

# Limpiar cache
bin/rails tmp:clear

# Optimizar base de datos
bin/rails db:optimize

# Backup de base de datos
bin/rails db:backup

# Verificar integridad de datos
bin/rails system:check_integrity
```

## 🗂️ Estructura del Proyecto

```
smash-seeding-chile/
├── app/
│   ├── controllers/           # Controladores MVC
│   │   ├── tournaments_controller.rb
│   │   ├── players_controller.rb
│   │   ├── events_controller.rb
│   │   └── seeds_controller.rb
│   ├── models/               # Modelos ActiveRecord
│   │   ├── tournament.rb
│   │   ├── player.rb
│   │   ├── event.rb
│   │   └── event_seed.rb
│   ├── services/             # Lógica de negocio
│   │   ├── location_parser_service.rb
│   │   ├── start_gg_api_service.rb
│   │   ├── tournament_sync_service.rb
│   │   └── character_sync_service.rb
│   ├── views/                # Vistas ERB + Turbo
│   │   ├── tournaments/
│   │   ├── players/
│   │   ├── events/
│   │   └── seeds/
│   ├── javascript/           # Stimulus controllers
│   │   └── controllers/
│   ├── assets/              # Assets estáticos
│   │   ├── images/
│   │   │   └── smash/       # Iconos de personajes
│   │   └── stylesheets/
│   └── helpers/             # Helpers de vistas
├── config/
│   ├── routes.rb            # Rutas de la aplicación
│   ├── database.yml         # Configuración BD
│   ├── locales/            # Archivos de localización
│   │   └── es.yml          # Español
│   └── environments/        # Configuraciones por ambiente
├── lib/
│   └── tasks/               # Tareas rake personalizadas
│       ├── smash_sync.rake
│       ├── tournament_management.rake
│       ├── location_management.rake
│       └── player_management.rake
├── db/
│   ├── migrate/            # Migraciones de BD
│   └── seeds.rb           # Datos iniciales
├── spec/                   # Tests RSpec
├── public/                # Assets públicos
└── tmp/                   # Archivos temporales
```

## 🌐 Funcionalidades Destacadas

### Detección Automática de Torneos Online
El sistema detecta automáticamente torneos online basándose en:
- Palabras clave en `venue_address` (online, wifi, discord, etc.)
- Marcado específico para `venue_address: "Chile"`
- Análisis de nombres de torneos

### Parser Inteligente de Ubicaciones
- Mapea direcciones chilenas a ciudades y regiones
- Reconoce todas las regiones administrativas de Chile
- Maneja casos especiales y variaciones de nombres
- Actualización automática al sincronizar torneos

### Gestión de Rate Limits
- Respeta los límites de la API de Start.gg (80 req/min)
- Cola inteligente de sincronización
- Reintentos automáticos en caso de errores
- Logging detallado de operaciones

### Interfaz Responsive
- Diseño optimizado para mobile y desktop
- Búsqueda en tiempo real con Turbo
- Filtros avanzados persistentes
- Paginación eficiente con Kaminari
- Pluralización correcta en español

### Gestión de Personajes
- Iconos de personajes de Smash Ultimate
- Soporte para skins alternativas
- Sincronización automática desde SSBWiki
- Visualización en tablas de seeds

## 📊 Estadísticas del Sistema

El sistema actualmente gestiona:
- **1,400+** torneos sincronizados
- **100+** jugadores registrados
- **15** regiones de Chile cubiertas
- **2,000+** eventos de torneos
- **109** torneos online identificados automáticamente
- **80+** personajes de Smash Ultimate con iconos

## 🔧 Configuración Avanzada

### Variables de Entorno Completas
```bash
# .env
START_GG_API_TOKEN=tu_token_aqui
RAILS_ENV=development
DATABASE_URL=sqlite3:db/development.sqlite3

# Configuraciones opcionales
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Para producción
SECRET_KEY_BASE=tu_secret_key_base_aqui
```

### Personalización de Ubicaciones
El sistema permite agregar nuevas palabras clave para detección de torneos online en:
```ruby
# app/services/location_parser_service.rb
def build_online_keywords
  # Agregar nuevas palabras clave aquí
end
```

### Configuración de Rate Limits
```ruby
# config/initializers/start_gg_api.rb
START_GG_RATE_LIMIT = 80 # requests per minute
START_GG_RETRY_DELAY = 5 # seconds
```

## 🚨 Solución de Problemas Comunes

### Error de Token de API
```bash
# Verificar que el token esté configurado
echo $START_GG_API_TOKEN

# O verificar en Rails console
bin/rails console
> ENV['START_GG_API_TOKEN']
```

### Problemas de Base de Datos
```bash
# Resetear base de datos
bin/rails db:drop db:create db:migrate db:seed

# Verificar migraciones pendientes
bin/rails db:migrate:status
```

### Problemas de Assets
```bash
# Limpiar y recompilar assets
bin/rails assets:clobber
bin/rails assets:precompile
```

### Rate Limit Excedido
```bash
# Verificar logs para errores de rate limit
tail -f log/development.log | grep "rate limit"

# Usar comandos con límites más bajos
bin/rails tournaments:sync_all_missing[10]
```

## 🧪 Testing

### Ejecutar Tests
```bash
# Todos los tests
bundle exec rspec

# Tests específicos
bundle exec rspec spec/models/
bundle exec rspec spec/controllers/
bundle exec rspec spec/services/

# Con coverage
COVERAGE=true bundle exec rspec
```

### Tests de Integración
```bash
# Tests del sistema completo
bundle exec rspec spec/system/

# Tests de API
bundle exec rspec spec/requests/
```

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agrega nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

### Estándares de Código
- Seguir las convenciones de Ruby y Rails
- Usar RuboCop para linting
- Escribir tests para nuevas funcionalidades
- Documentar cambios en el README

## 📝 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 🆘 Soporte

Para reportar bugs o solicitar funcionalidades:
- Abre un [Issue](https://github.com/tu-usuario/smash-seeding-chile/issues)
- Contacta al equipo de desarrollo
- Revisa la documentación en el wiki

## 📈 Roadmap

### Próximas Funcionalidades
- [ ] Integración con más APIs de torneos
- [ ] Sistema de rankings automático
- [ ] Notificaciones push para nuevos torneos
- [ ] Dashboard de analytics avanzado
- [ ] Exportación de datos en múltiples formatos
- [ ] API REST para desarrolladores
- [ ] Sistema de autenticación de usuarios
- [ ] Gestión de favoritos de torneos

### Mejoras Técnicas
- [ ] Migración a PostgreSQL para producción
- [ ] Implementación de Redis para cache
- [ ] Dockerización del proyecto
- [ ] CI/CD con GitHub Actions
- [ ] Monitoreo con Sentry
- [ ] Optimización de consultas SQL

## 🙏 Agradecimientos

- **Start.gg** por proporcionar la API de datos de torneos
- **SSBWiki** por la información de personajes
- **Comunidad chilena de Smash** por el feedback y testing
- **Contribuidores** del proyecto

---

**Desarrollado con ❤️ para la comunidad chilena de Super Smash Bros. Ultimate**

### 📞 Contacto

- **Desarrollador Principal**: [Tu Nombre]
- **Email**: tu-email@ejemplo.com
- **Discord**: TuUsuario#1234
- **Twitter**: @TuUsuario

### 🔗 Enlaces Útiles

- [Start.gg API Documentation](https://developer.start.gg/docs/intro)
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Hotwire Documentation](https://hotwired.dev/)
