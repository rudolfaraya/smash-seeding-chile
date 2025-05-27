# Guía de Jobs de Sincronización

Esta guía explica cómo usar el sistema de jobs para gestionar todas las tareas de sincronización de la aplicación Smash Seeding Chile.

## 🏗️ Arquitectura de Jobs

### Jobs Disponibles

1. **SyncTournamentsJob** - Sincronización general de torneos
2. **SyncNewTournamentsJob** - Sincronización de nuevos torneos únicamente
3. **SyncTournamentEventsJob** - Sincronización de eventos de un torneo específico
4. **SyncEventSeedsJob** - Sincronización de seeds de un evento específico
5. **SyncTournamentJob** - Sincronización completa de un torneo (eventos + seeds)
6. **SyncAllTournamentsJob** - Sincronización masiva de torneos que necesitan datos
7. **UpdatePlayersJob** - Actualización de información de jugadores

### Colas de Prioridad

- **high_priority**: Jobs críticos (sincronización general, nuevos torneos)
- **default**: Jobs estándar (eventos, seeds individuales)
- **low_priority**: Jobs masivos (sincronización de todos los torneos)

## 🚀 Uso desde la Interfaz Web

### Controladores Actualizados

Todas las acciones de sincronización en los controladores ahora usan jobs:

- **Torneos**: `/tournaments/sync` → `SyncTournamentsJob`
- **Nuevos Torneos**: `/tournaments/sync_new_tournaments` → `SyncNewTournamentsJob`
- **Eventos**: `/tournaments/:id/sync_events` → `SyncTournamentEventsJob`
- **Seeds**: `/tournaments/:tournament_id/events/:id/sync_seeds` → `SyncEventSeedsJob`

### Monitoreo

- **Mission Control**: Disponible en `/jobs`
- Muestra jobs en cola, completados y fallidos
- Permite ver detalles de ejecución y errores

## 📋 Comandos Rake

### Comandos Básicos

```bash
# Ver estado de la cola
rails sync:status

# Sincronización general de torneos
rails sync:tournaments

# Sincronización de nuevos torneos
rails sync:new_tournaments

# Sincronización masiva (opcional: límite)
rails sync:all_tournaments[10]
```

### Comandos Específicos

```bash
# Sincronizar eventos de un torneo específico
rails sync:tournament_events[123]

# Sincronizar seeds de un evento específico
rails sync:event_seeds[456]

# Con opciones adicionales (force, update_players)
rails sync:event_seeds[456,true,true]

# Sincronización completa de un torneo
rails sync:tournament_complete[123]

# Con force
rails sync:tournament_complete[123,true]
```

### Actualización de Jugadores

```bash
# Actualizar jugadores (batch size por defecto: 25)
rails sync:players

# Con batch size personalizado
rails sync:players[50]

# Con force update
rails sync:players[25,true]
```

## 🧪 Pruebas

### Script de Prueba

```bash
# Ejecutar script de prueba completo
ruby test_jobs.rb
```

Este script:
- Verifica que todas las clases de jobs existen
- Prueba la creación de jobs sin ejecutarlos
- Muestra estadísticas de la cola
- Proporciona comandos útiles

### Verificación Manual

```ruby
# En rails console
job = SyncTournamentsJob.perform_later
puts "Job ID: #{job.job_id}"

# Ver jobs en cola
SolidQueue::Job.where(finished_at: nil).count

# Ver jobs completados
SolidQueue::Job.where.not(finished_at: nil).count

# Ver jobs fallidos
SolidQueue::FailedExecution.count
```

## 📊 Monitoreo y Debugging

### Mission Control

Accede a `/jobs` para:
- Ver jobs en tiempo real
- Monitorear progreso
- Ver errores y stack traces
- Reintenter jobs fallidos

### Logs

Los jobs escriben logs detallados:

```bash
# Ver logs en desarrollo
tail -f log/development.log | grep -E "(🏆|🆕|📋|🌱|👥|✅|❌)"
```

### Comandos de Estado

```bash
# Estado completo de la cola
rails sync:status

# Jobs recientes
SolidQueue::Job.order(created_at: :desc).limit(10)

# Jobs fallidos
SolidQueue::FailedExecution.order(created_at: :desc).limit(5)
```

## ⚙️ Configuración

### Colas de Prioridad

En `config/environments/development.rb`:

```ruby
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

### Rate Limiting

Los jobs incluyen pausas automáticas para respetar los rate limits de la API:
- 2 segundos entre eventos
- 5 segundos entre torneos
- 10 segundos en caso de error

## 🔧 Troubleshooting

### Jobs Fallidos

1. **Ver detalles del error**:
   ```bash
   rails sync:status
   ```

2. **En Mission Control**: Ir a `/jobs` y revisar la sección de jobs fallidos

3. **Reintenter job fallido**:
   - Desde Mission Control: botón "Retry"
   - Desde consola: `SolidQueue::FailedExecution.find(id).retry`

### Jobs Bloqueados

Si los jobs no se procesan:

1. **Verificar worker**:
   ```bash
   # En desarrollo, el worker debería estar corriendo automáticamente
   ps aux | grep solid_queue
   ```

2. **Reiniciar servidor**:
   ```bash
   bin/dev
   ```

### Problemas de Base de Datos

Si hay errores de conexión a la base de datos de queue:

1. **Verificar configuración**:
   ```bash
   rails db:migrate
   ```

2. **Recrear base de datos de queue** (si es necesaria):
   ```bash
   # Solo si usas base de datos separada
   rails db:create
   rails db:migrate
   ```

## 📈 Mejores Prácticas

### Uso Recomendado

1. **Para sincronización regular**: Usar `SyncNewTournamentsJob`
2. **Para datos faltantes**: Usar `SyncAllTournamentsJob` con límite
3. **Para torneos específicos**: Usar `SyncTournamentJob`
4. **Para debugging**: Usar jobs individuales (`SyncEventSeedsJob`)

### Monitoreo

1. **Revisar Mission Control regularmente**: `/jobs`
2. **Usar `rails sync:status`** para verificaciones rápidas
3. **Monitorear logs** para errores de API

### Performance

1. **Usar límites** en sincronización masiva
2. **Programar jobs** en horarios de menor tráfico
3. **Monitorear rate limits** de la API de Start.gg

## 🔗 Enlaces Útiles

- **Mission Control**: `/jobs`
- **Logs**: `log/development.log`
- **Documentación Solid Queue**: [GitHub](https://github.com/rails/solid_queue)
- **Documentación Mission Control**: [GitHub](https://github.com/rails/mission_control-jobs)

## 📝 Notas Importantes

- Todos los jobs respetan los rate limits de la API
- Los jobs incluyen manejo de errores robusto
- Mission Control permite monitoreo en tiempo real
- Los jobs pueden ser reintentados automáticamente en caso de fallo
- La base de datos de queue está separada de la aplicación principal 