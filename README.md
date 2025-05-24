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

### 🎯 Eventos y Seeds
- **Gestión de eventos** por torneo (Singles, Doubles, etc.)
- **Sincronización de seeds** y brackets
- **Seguimiento del estado** de sincronización
- **Visualización detallada** de participantes por evento

### 🔧 Herramientas Administrativas
- **Comandos rake especializados** para mantenimiento
- **Sincronización masiva** con control de rate limits

## 🛠️ Tecnologías Utilizadas

### Backend
- **Ruby 3.3.2** - Lenguaje de programación
- **Rails 7.2.2** - Framework web
- **SQLite3** - Base de datos (desarrollo)
- **Puma** - Servidor web

### Frontend
- **Hotwire (Turbo + Stimulus)** - Interactividad SPA-like
- **Tailwind CSS** - Framework CSS para diseño responsive
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

## 📦 Instalación

### Prerrequisitos
- Ruby 3.3.2
- Node.js (para assets)
- SQLite3

### Pasos de instalación

1. **Clonar el repositorio**
```bash
git clone https://github.com/tu-usuario/smash-seeding-chile.git
cd smash-seeding-chile
```

2. **Instalar dependencias**
```bash
bundle install
```

3. **Configurar variables de entorno**
```bash
cp .env.example .env
# Editar .env con tus credenciales de Start.gg API
```

4. **Configurar base de datos**
```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

5. **Levantar el servidor**
```bash
bin/dev  # Desarrollo con CSS hot-reload
# O simplemente:
bin/rails server
```

La aplicación estará disponible en `http://localhost:3000`

## 🚀 Comandos Rake Disponibles

### Sincronización de Torneos
```bash
# Sincronizar datos de Smash Ultimate desde Start.gg
bin/rails smash:sync

# Sincronizar todos los torneos faltantes (respeta rate limits)
bin/rails tournaments:sync_all_missing[limit]

# Sincronizar torneo específico
bin/rails tournament:sync_complete[tournament_id]

# Sincronizar solo eventos nuevos
bin/rails tournaments/sync_new_tournaments
```

### Gestión de Ubicaciones
```bash
# Parsear ubicaciones de todos los torneos
bin/rails tournaments:parse_locations

# Reparsear ubicaciones específicas
bin/rails tournaments:reparse_locations[tournament_ids]

# Detectar torneos online automáticamente
bin/rails tournaments:detect_online_tournaments

# Marcar torneos con venue_address "Chile" como online
bin/rails tournaments:mark_chile_as_online

# Mostrar estadísticas de ubicaciones
bin/rails tournaments:location_stats
```

### Información y Estadísticas
```bash
# Mostrar información de un torneo
bin/rails tournament:info[tournament_id]

# Buscar torneo por nombre
bin/rails tournament:search[query]

# Listar torneos que necesitan sincronización
bin/rails tournaments:list_missing

# Verificar URLs de Start.gg
bin/rails tournaments:check_start_gg_urls

# Mostrar torneos con venue_address "Chile"
bin/rails tournaments:show_chile_tournaments

# Revisar torneos que podrían ser online
bin/rails tournaments:check_potential_online
```

## 🗂️ Estructura del Proyecto

```
app/
├── controllers/           # Controladores MVC
│   ├── tournaments_controller.rb
│   ├── players_controller.rb
│   └── events_controller.rb
├── models/               # Modelos ActiveRecord
│   ├── tournament.rb
│   ├── player.rb
│   ├── event.rb
│   └── event_seed.rb
├── services/             # Lógica de negocio
│   ├── location_parser_service.rb
│   ├── start_gg_api_service.rb
│   └── tournament_sync_service.rb
├── views/                # Vistas ERB + Turbo
│   ├── tournaments/
│   ├── players/
│   └── events/
└── javascript/           # Stimulus controllers
    └── controllers/

config/
├── routes.rb            # Rutas de la aplicación
├── database.yml         # Configuración BD
└── environments/        # Configuraciones por ambiente

lib/
└── tasks/               # Tareas rake personalizadas
    ├── smash_sync.rake
    ├── tournament_management.rake
    └── location_management.rake
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

## 📊 Estadísticas del Sistema

El sistema actualmente gestiona:
- **1,400+** torneos sincronizados
- **100+** jugadores registrados
- **15** regiones de Chile cubiertas
- **2,000+** eventos de torneos
- **109** torneos online identificados automáticamente

## 🔧 Configuración Avanzada

### Variables de Entorno
```bash
# .env
START_GG_API_TOKEN=tu_token_aqui
RAILS_ENV=development
DATABASE_URL=sqlite3:db/development.sqlite3
```

### Personalización de Ubicaciones
El sistema permite agregar nuevas palabras clave para detección de torneos online en:
```ruby
# app/services/location_parser_service.rb
def build_online_keywords
  # Agregar nuevas palabras clave aquí
end
```

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agrega nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 🆘 Soporte

Para reportar bugs o solicitar funcionalidades:
- Abre un [Issue](https://github.com/tu-usuario/smash-seeding-chile/issues)
- Contacta al equipo de desarrollo

## 📈 Roadmap

- [ ] Integración con más APIs de torneos
- [ ] Sistema de rankings automático
- [ ] Notificaciones push para nuevos torneos
- [ ] Dashboard de analytics avanzado
- [ ] Exportación de datos en múltiples formatos

---

**Desarrollado con ❤️ para la comunidad chilena de Super Smash Bros. Ultimate**
