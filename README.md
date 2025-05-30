# 🎮 Smash Seeding Chile

**Sistema de gestión y sincronización de torneos de Super Smash Bros. Ultimate en Chile**

[![Ruby](https://img.shields.io/badge/Ruby-3.3.2-red.svg)](https://www.ruby-lang.org/en/)
[![Rails](https://img.shields.io/badge/Rails-7.2.2-red.svg)](https://rubyonrails.org/)
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
- **Rails 7.2.2** - Framework web
- **SQLite3** - Base de datos (desarrollo)
- **Puma** - Servidor web

### Frontend
- **Hotwire (Turbo + Stimulus)** - Interactividad SPA-like
- **Tailwind CSS 3** - Framework CSS para diseño responsive
- **Importmap** - Gestión de módulos JavaScript

### APIs y Servicios
- **Start.gg API** - Fuente de datos de torneos
- **SSBWiki** - Información adicional de personajes (assets)

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
├── scripts/                 # 🆕 Scripts de análisis y administración
│   ├── analyze_duplicate_players.rb     # Análisis duplicados
│   ├── merge_duplicate_players.rb       # Merge de duplicados
│   ├── generate_character_report.rb     # Reportes personajes
│   ├── export_to_csv.rb                # Exportación CSV
│   ├── simple_combinations_export.rb   # Exportación simple
│   ├── character_combinations_query.rb # Consultas combinaciones
│   ├── simple_character_query.rb       # Consultas simples
│   ├── one_liner_query.rb              # Consultas rápidas
│   ├── sync_events_without_attendees.rb # Sync discrepancias
│   ├── sync_events_without_seeds.rb    # Sync sin seeds
│   ├── sync_all_events_discrepancies.rb # Sync completa
│   ├── bulk_update_events_discrepancies.rb # Update masiva
│   ├── analyze_attendees_discrepancies.rb # Análisis asistentes
│   ├── test_attendees_fix.rb           # Pruebas correcciones
│   ├── test_auth_restrictions.rb       # Pruebas auth
│   └── test_startgg_bug.sh            # Pruebas bugs API
├── config/
│   ├── routes.rb            # Rutas de la aplicación
│   ├── database.yml         # Configuración BD
│   ├── locales/            # Archivos de localización
│   │   └── es.yml          # Español
│   └── environments/        # Configuraciones por ambiente
├── lib/
│   └── tasks/               # Tareas rake personalizadas
│       ├── sync_smash.rake              # Sincronización básica
│       ├── sync_all_tournaments.rake    # Sincronización masiva
│       ├── sync_tournament_complete.rake # Sincronización completa
│       ├── players.rake                 # Gestión de jugadores
│       ├── parse_tournament_locations.rake # Procesamiento ubicaciones
│       ├── mark_chile_online.rake       # Detección torneos online
│       ├── download_smash_assets.rake   # Descarga de assets
│       ├── extract_character_skins.rake # Extracción de skins
│       ├── clean_events.rake           # Limpieza de eventos
│       ├── update_attendees_count.rake # Corrección asistentes
│       ├── sync_jobs.rake              # Trabajos de sincronización
│       ├── sync_start_gg_urls.rake     # URLs de Start.gg
│       └── update_events_videogame_info.rake # Info videojuegos
├── db/
│   ├── migrate/            # Migraciones de BD
│   └── seeds.rb           # Datos iniciales
├── spec/                   # Tests RSpec
├── public/                # Assets públicos
└── tmp/                   # Archivos temporales
```

## 📋 **Tareas Rake Detalladas**

### 🚀 **Sincronización Principal**

#### **`bin/rails smash:sync`**
Sincronización básica de datos de Smash Ultimate desde Start.gg.
```bash
bin/rails smash:sync
```

#### **`bin/rails tournaments:sync_all_missing[limit]`**
Sincroniza todos los torneos faltantes con límite opcional.
```bash
# Sincronizar hasta 50 torneos
bin/rails tournaments:sync_all_missing[50]

# Sin límite (usar con precaución)
bin/rails tournaments:sync_all_missing
```

#### **`bin/rails tournament:sync_complete[tournament_id]`**
Sincronización completa de un torneo específico (torneo + eventos + seeds).
```bash
bin/rails tournament:sync_complete[123456]
```

### 🎯 **Gestión de Eventos**

#### **`bin/rails tournaments:sync_all_events`**
Sincroniza eventos para todos los torneos existentes.
```bash
bin/rails tournaments:sync_all_events
```

#### **`bin/rails events:sync_all_seeds`**
Sincroniza seeds para todos los eventos existentes.
```bash
bin/rails events:sync_all_seeds
```

#### **`bin/rails event:sync_seeds[event_id]`**
Sincroniza seeds de un evento específico.
```bash
bin/rails event:sync_seeds[789012]
```

#### **`bin/rails events:clean_orphaned`**
Limpia eventos huérfanos sin torneos asociados.
```bash
bin/rails events:clean_orphaned
```

#### **`bin/rails events:update_attendees_count`**
Actualiza conteos de asistentes basado en seeds reales.
```bash
bin/rails events:update_attendees_count
```

### 🗺️ **Gestión de Ubicaciones y Detección Online**

#### **`bin/rails tournaments:parse_locations`**
Parsea ubicaciones de todos los torneos usando el LocationParserService.
```bash
bin/rails tournaments:parse_locations
```

#### **`bin/rails tournaments:reparse_locations[tournament_ids]`**
Re-parsea ubicaciones específicas.
```bash
bin/rails tournaments:reparse_locations[123,456,789]
```

#### **`bin/rails tournaments:detect_online_tournaments`**
Detecta automáticamente torneos online basado en palabras clave.
```bash
bin/rails tournaments:detect_online_tournaments
```

#### **`bin/rails tournaments:mark_chile_as_online`**
Marca torneos con venue_address "Chile" como online.
```bash
bin/rails tournaments:mark_chile_as_online
```

#### **`bin/rails tournaments:location_stats`**
Muestra estadísticas detalladas de ubicaciones parseadas.
```bash
bin/rails tournaments:location_stats
```

### 👥 **Gestión de Jugadores**

#### **`bin/rails players:sync_all`**
Sincroniza información de todos los jugadores desde Start.gg.
```bash
bin/rails players:sync_all
```

#### **`bin/rails player:sync[player_id]`**
Sincroniza un jugador específico.
```bash
bin/rails player:sync[123456]
```

#### **`bin/rails players:update_stats`**
Actualiza estadísticas calculadas de todos los jugadores.
```bash
bin/rails players:update_stats
```

#### **`bin/rails players:clean_duplicates`**
Identifica y reporta jugadores duplicados potenciales.
```bash
bin/rails players:clean_duplicates
```

#### **`bin/rails players:merge[base_id,merge_id]`**
Merge manual de dos jugadores específicos.
```bash
bin/rails players:merge[123,456]
```

### 🎮 **Gestión de Personajes y Assets**

#### **`bin/rails characters:download_all_assets`**
Descarga todos los assets de personajes desde fuentes oficiales.
```bash
bin/rails characters:download_all_assets
```

#### **`bin/rails characters:extract_skins`**
Extrae y organiza skins de personajes.
```bash
bin/rails characters:extract_skins
```

#### **`bin/rails characters:sync_icons`**
Sincroniza iconos de personajes desde SSBWiki.
```bash
bin/rails characters:sync_icons
```

#### **`bin/rails characters:update_info`**
Actualiza información de personajes desde fuentes externas.
```bash
bin/rails characters:update_info
```

#### **`bin/rails characters:check_assets`**
Verifica integridad de assets de personajes.
```bash
bin/rails characters:check_assets
```

### 🔧 **Mantenimiento y Limpieza**

#### **`bin/rails tournaments:sync_start_gg_urls`**
Sincroniza y valida URLs de Start.gg para todos los torneos.
```bash
bin/rails tournaments:sync_start_gg_urls
```

#### **`bin/rails tournaments:check_start_gg_urls`**
Verifica la validez de URLs de Start.gg existentes.
```bash
bin/rails tournaments:check_start_gg_urls
```

#### **`bin/rails events:update_videogame_info`**
Actualiza información de videojuegos para eventos.
```bash
bin/rails events:update_videogame_info
```

#### **`bin/rails sync:jobs_status`**
Muestra estado de trabajos de sincronización en curso.
```bash
bin/rails sync:jobs_status
```

#### **`bin/rails sync:cleanup_failed_jobs`**
Limpia trabajos de sincronización fallidos.
```bash
bin/rails sync:cleanup_failed_jobs
```

### 📊 **Información y Estadísticas**

#### **`bin/rails tournament:info[tournament_id]`**
Muestra información detallada de un torneo.
```bash
bin/rails tournament:info[123456]
```

#### **`bin/rails tournament:search[query]`**
Busca torneos por nombre.
```bash
bin/rails tournament:search["Smash Factor"]
```

#### **`bin/rails tournaments:list_missing`**
Lista torneos que necesitan sincronización.
```bash
bin/rails tournaments:list_missing
```

#### **`bin/rails tournaments:show_chile_tournaments`**
Muestra torneos marcados con venue_address "Chile".
```bash
bin/rails tournaments:show_chile_tournaments
```

#### **`bin/rails system:stats`**
Muestra estadísticas generales del sistema.
```bash
bin/rails system:stats
```

#### **`bin/rails db:backup`**
Crea backup de la base de datos.
```bash
bin/rails db:backup
```

#### **`bin/rails system:check_integrity`**
Verifica integridad de datos del sistema.
```bash
bin/rails system:check_integrity
```

## 🎯 **Flujos de Trabajo Recomendados**

### 🔍 **Limpieza de Jugadores Duplicados**

**Flujo completo recomendado**:

1. **Análisis inicial**:
```bash
ruby scripts/analyze_duplicate_players.rb
```

2. **Revisión interactiva** (RECOMENDADO):
```bash
ruby scripts/merge_duplicate_players.rb interactive duplicate_players_analysis_[fecha].csv 0.7
```

3. **Criterios de decisión**:
   - **MERGE**: Sin eventos en común, información consistente
   - **SKIP**: Eventos en común (≥5), información contradictoria, diferentes equipos
   - **SIMULATE**: Casos dudosos para revisar transferencias

4. **Verificación post-merge**:
```bash
# Ejecutar análisis nuevamente para verificar mejoras
ruby scripts/analyze_duplicate_players.rb
```

### 📊 **Sincronización y Análisis de Datos**

**Para mantener datos actualizados**:

1. **Sincronización básica**:
```bash
bin/rails smash:sync
```

2. **Corrección de discrepancias**:
```bash
ruby scripts/sync_all_events_discrepancies.rb
```

3. **Análisis de calidad de datos**:
```bash
ruby scripts/analyze_attendees_discrepancies.rb
```

4. **Generación de reportes**:
```bash
ruby scripts/generate_character_report.rb
ruby scripts/character_combinations_query.rb
```

### 🎮 **Análisis de Meta Competitivo**

**Para análisis de personajes y tendencias**:

1. **Reporte básico de personajes**:
```bash
ruby scripts/simple_character_query.rb
```

2. **Análisis detallado**:
```bash
ruby scripts/generate_character_report.rb
```

3. **Combinaciones y meta**:
```bash
ruby scripts/character_combinations_query.rb
```

4. **Exportación para análisis externo**:
```bash
ruby scripts/export_to_csv.rb
ruby scripts/simple_combinations_export.rb
```

## ⚠️ **Precauciones Importantes**

### 🔒 **Seguridad en Merges**
- **SIEMPRE** ejecutar en modo simulación primero (`dry_run: true`)
- **REVISAR** cuidadosamente las "señales de alarma" en modo interactivo
- **HACER BACKUP** de la base de datos antes de merges masivos
- **NO** mergear jugadores con muchos eventos en común (probablemente son diferentes personas)

### 📊 **Rate Limits y APIs**
- Todos los scripts respetan los límites de Start.gg API (80 req/min)
- Usar con moderación para evitar bloqueos temporales
- Logs detallados disponibles en `log/` para debugging

### 🔄 **Integridad de Datos**
- Los scripts incluyen validaciones antes de modificar datos
- Transacciones con rollback automático en errores
- Verificación de integridad referencial antes de eliminaciones

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
- **1,400+** jugadores sincronizados
- **2,000+** eventos de torneos

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
bin/rails db:drop db:create db:migrate

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
- [ ] Dashboard de analytics avanzado
- [ ] Exportación de datos en múltiples formatos
- [ ] Sistema de autenticación de usuarios
- [ ] Gestión de teams de jugadores

### Mejoras Técnicas
- [ ] Migración a PostgreSQL para producción
- [ ] Uso de Active Jobs con monitoreo de Mission Control
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

- **Desarrollador Principal**: Rodolfo Araya
- **Email**: rudolfaraya@gmail.com
- **Twitter**: @rudolfaraya2

### 🔗 Enlaces Útiles

- [Start.gg API Documentation](https://developer.start.gg/docs/intro)
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Hotwire Documentation](https://hotwired.dev/)

# 🛠️ Scripts y Herramientas Disponibles

## 📂 Ubicación de Scripts

Todos los scripts están organizados en el directorio `scripts/` para mantener el proyecto ordenado:

```
scripts/
├── analyze_duplicate_players.rb      # Análisis de jugadores duplicados
├── merge_duplicate_players.rb        # Merge de duplicados (múltiples modos)
├── generate_character_report.rb      # Reportes de personajes
├── export_to_csv.rb                  # Exportación a CSV
├── simple_combinations_export.rb     # Exportación simple
├── character_combinations_query.rb   # Consultas de combinaciones
├── simple_character_query.rb         # Consultas simples
├── one_liner_query.rb               # Consultas de una línea
├── sync_events_without_attendees.rb  # Sincronización discrepancias
├── sync_events_without_seeds.rb      # Sincronización sin seeds
├── sync_all_events_discrepancies.rb # Sincronización completa
├── bulk_update_events_discrepancies.rb # Actualización masiva
├── analyze_attendees_discrepancies.rb # Análisis asistentes
├── test_attendees_fix.rb            # Pruebas de correcciones
├── test_auth_restrictions.rb        # Pruebas de autenticación
└── test_startgg_bug.sh              # Pruebas de bugs Start.gg
```

## 📊 Scripts de Análisis y Gestión de Jugadores

### 🔍 **analyze_duplicate_players.rb**
**Propósito**: Identificar jugadores duplicados con nombres similares en la base de datos.

**Funcionalidades**:
- Normalización de nombres removiendo prefijos de equipos (SF, CL, SCL, VLP, etc.)
- Algoritmos de similitud: Levenshtein, Jaccard, contención de strings
- Score de actividad basado en eventos, torneos, cuenta de usuario, equipos y actividad reciente
- Optimización por agrupación inicial para reducir comparaciones (de 68M a mucho menos)
- Generación de reporte CSV con recomendaciones de merge

**Uso**:
```bash
# Análisis completo con configuración por defecto
ruby scripts/analyze_duplicate_players.rb

# Personalización de parámetros dentro del script:
# - Umbral de similitud: 0.8 (80%)
# - Mínimo de eventos para considerar: 2
# - Filtros por ratio de longitud de nombres
```

**Salida**: Archivo CSV con columnas:
- Base Player ID, Entrant Name, Events Count, Activity Score
- Merge Candidate ID, Entrant Name, Events Count, Activity Score  
- Similarity Score, Confidence Level, Recommendation

### 🔄 **merge_duplicate_players.rb**
**Propósito**: Realizar merge de jugadores duplicados con diferentes modos de operación.

**Modos disponibles**:

#### **Modo Interactivo** (Recomendado)
```bash
ruby scripts/merge_duplicate_players.rb interactive archivo_csv [umbral]
```
- Revisión caso por caso con información detallada
- Detección de "señales de alarma" (eventos en común, información contradictoria)
- Opciones: [m]erge, [s]imular, [s]kip, [q]uit, [h]elp
- Comparación inteligente de campos (país, ciudad, Twitter, equipos, personajes)
- Análisis de períodos de actividad y solapamiento temporal

#### **Modo Batch**
```bash
ruby scripts/merge_duplicate_players.rb batch archivo_csv [umbral] [dry_run]
```
- Merge automático basado en umbral de confianza
- Simulación por defecto (dry_run=true)

#### **Modo Manual**
```bash
ruby scripts/merge_duplicate_players.rb manual
```
- Input interactivo de IDs de jugadores para merge específico

#### **Merge Directo**
```bash
ruby scripts/merge_duplicate_players.rb merge [base_id] [merge_id] [dry_run]
```
- Merge directo entre dos jugadores específicos

**Operaciones del merge**:
- Transferencia de event_seeds (manejo inteligente de duplicados)
- Transferencia de relaciones de equipos (PlayerTeam)
- Sincronización de información de perfil (país, ciudad, Twitter, etc.)
- Manejo de asociaciones de usuarios (User)
- Transacciones con rollback automático en caso de errores
- Validaciones de seguridad antes de cada operación

### 📈 **Scripts de Análisis de Datos**

#### **generate_character_report.rb**
Genera reportes detallados sobre el uso de personajes en la escena competitiva.

```bash
ruby scripts/generate_character_report.rb
```

**Funcionalidades**:
- Estadísticas de uso por personaje
- Análisis de tendencias temporales
- Identificación de personajes más populares por región
- Exportación en formato de texto (.txt)
- Top 15 personajes más populares con porcentajes
- Análisis de distribución de skins utilizadas
- Identificación de personajes no utilizados

**Salida**: Archivo `character_combinations_report_[timestamp].txt` con análisis completo.

#### **character_combinations_query.rb**
Analiza combinaciones de personajes utilizadas por los jugadores.

```bash
ruby scripts/character_combinations_query.rb
```

**Salidas**:
- Combinaciones más comunes de mains/secondaries
- Análisis de diversidad de personajes por jugador
- Reportes de meta competitivo
- Consultas SQL optimizadas
- Estadísticas detalladas por personaje

#### **simple_character_query.rb**
Consultas rápidas sobre estadísticas de personajes.

```bash
ruby scripts/simple_character_query.rb
```

**Funcionalidades**:
- Reporte rápido de combinaciones únicas
- Estadísticas básicas de uso
- Listado de personajes y skins

#### **one_liner_query.rb**
Consultas de una línea para análisis exploratorio rápido.

```bash
ruby scripts/one_liner_query.rb
```

### 🔄 **Scripts de Sincronización**

#### **sync_events_without_attendees.rb**
Sincroniza eventos que tienen discrepancias en el conteo de asistentes.

```bash
ruby scripts/sync_events_without_attendees.rb
```

**Funcionalidades**:
- Identifica eventos con attendees_count = 0 pero con seeds
- Sincronización masiva con control de rate limits (80 req/min)
- Logging detallado de operaciones y progreso
- Reintento automático en errores de API
- Estadísticas de tiempo y éxito/fallo
- Análisis de completitud de seeds

#### **sync_events_without_seeds.rb**
Sincroniza eventos que no tienen seeds pero deberían tenerlos.

```bash
ruby scripts/sync_events_without_seeds.rb
```

**Funcionalidades**:
- Identifica eventos nunca sincronizados (sin seeds)
- Control de rate limits respetando API de Start.gg
- Logging detallado del progreso
- Estadísticas finales de sincronización
- Análisis de jugadores con/sin cuenta

#### **sync_all_events_discrepancies.rb**
Análisis y corrección completa de discrepancias en eventos.

```bash
ruby scripts/sync_all_events_discrepancies.rb
```

**Funcionalidades**:
- Detección de múltiples tipos de discrepancias
- Corrección automática con validaciones
- Reportes de progreso y errores detallados
- Backup automático antes de cambios masivos
- Control exhaustivo de rate limits

#### **bulk_update_events_discrepancies.rb**
Actualización masiva de eventos con discrepancias identificadas.

```bash
ruby scripts/bulk_update_events_discrepancies.rb
```

### 📊 **Scripts de Análisis de Asistencia**

#### **analyze_attendees_discrepancies.rb**
Analiza discrepancias entre el número de asistentes reportado y los seeds reales.

```bash
ruby scripts/analyze_attendees_discrepancies.rb
```

**Salidas**:
- Identificación de eventos con conteos incorrectos
- Estadísticas de precisión de datos
- Recomendaciones de corrección automática
- Análisis de patrones en discrepancias

#### **test_attendees_fix.rb**
Prueba las correcciones de asistentes antes de aplicarlas en producción.

```bash
ruby scripts/test_attendees_fix.rb
```

### 📤 **Scripts de Exportación**

#### **export_to_csv.rb**
Exportación personalizada de datos del sistema a formato CSV.

```bash
ruby scripts/export_to_csv.rb
```

**Opciones de exportación**:
- Jugadores con estadísticas completas
- Eventos con información detallada
- Torneos con metadatos completos
- Seeds con información de brackets
- Formato CSV compatible con Excel/Google Sheets

**Salida**: Archivos `character_combinations_[timestamp].csv` y `character_stats_[timestamp].csv`

#### **simple_combinations_export.rb**
Exportación rápida de combinaciones de personajes en formato CSV.

```bash
ruby scripts/simple_combinations_export.rb
```

**Funcionalidades**:
- Exportación simplificada a CSV
- Incluye personajes principales y secundarios
- Compatible con análisis externos
- Archivo README automático con metadatos

**Salida**: Archivo `simple_combinations_[timestamp].csv` + README

### 🔧 **Scripts de Utilidades**

#### **test_auth_restrictions.rb**
Prueba restricciones de autenticación y autorización.

```bash
ruby scripts/test_auth_restrictions.rb
```

#### **test_startgg_bug.sh**
Script de shell para probar y documentar bugs conocidos de la API de Start.gg.

```bash
bash scripts/test_startgg_bug.sh
```

## 🎯 **Flujos de Trabajo Recomendados**

### 🔍 **Limpieza de Jugadores Duplicados**

**Flujo completo recomendado**:

1. **Análisis inicial**:
```bash
ruby scripts/analyze_duplicate_players.rb
```

2. **Revisión interactiva** (RECOMENDADO):
```bash
ruby scripts/merge_duplicate_players.rb interactive duplicate_players_analysis_[fecha].csv 0.7
```

3. **Criterios de decisión**:
   - **MERGE**: Sin eventos en común, información consistente
   - **SKIP**: Eventos en común (≥5), información contradictoria, diferentes equipos
   - **SIMULATE**: Casos dudosos para revisar transferencias

4. **Verificación post-merge**:
```bash
# Ejecutar análisis nuevamente para verificar mejoras
ruby scripts/analyze_duplicate_players.rb
```

### 📊 **Sincronización y Análisis de Datos**

**Para mantener datos actualizados**:

1. **Sincronización básica**:
```bash
bin/rails smash:sync
```

2. **Corrección de discrepancias**:
```bash
ruby scripts/sync_all_events_discrepancies.rb
```

3. **Análisis de calidad de datos**:
```bash
ruby scripts/analyze_attendees_discrepancies.rb
```

4. **Generación de reportes**:
```bash
ruby scripts/generate_character_report.rb
ruby scripts/character_combinations_query.rb
```

### 🎮 **Análisis de Meta Competitivo**

**Para análisis de personajes y tendencias**:

1. **Reporte básico de personajes**:
```bash
ruby scripts/simple_character_query.rb
```

2. **Análisis detallado**:
```bash
ruby scripts/generate_character_report.rb
```

3. **Combinaciones y meta**:
```bash
ruby scripts/character_combinations_query.rb
```

4. **Exportación para análisis externo**:
```bash
ruby scripts/export_to_csv.rb
ruby scripts/simple_combinations_export.rb
```

## ⚠️ **Precauciones Importantes**

### 🔒 **Seguridad en Merges**
- **SIEMPRE** ejecutar en modo simulación primero (`dry_run: true`)
- **REVISAR** cuidadosamente las "señales de alarma" en modo interactivo
- **HACER BACKUP** de la base de datos antes de merges masivos
- **NO** mergear jugadores con muchos eventos en común (probablemente son diferentes personas)

### 📊 **Rate Limits y APIs**
- Todos los scripts respetan los límites de Start.gg API (80 req/min)
- Usar con moderación para evitar bloqueos temporales
- Logs detallados disponibles en `log/` para debugging

### 🔄 **Integridad de Datos**
- Los scripts incluyen validaciones antes de modificar datos
- Transacciones con rollback automático en errores
- Verificación de integridad referencial antes de eliminaciones

### 🚀 **Ejecución de Scripts**
- Todos los scripts cargan automáticamente el entorno de Rails
- Se pueden ejecutar directamente desde línea de comandos
- También funcionan desde Rails console usando `load 'scripts/nombre_script.rb'`
