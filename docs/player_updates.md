# Actualización de Información de Jugadores

Este documento describe las funcionalidades para mantener actualizada la información de los jugadores desde la API de start.gg.

## Funcionalidades Principales

### 1. Actualización Automática durante Sincronización

La información de jugadores se actualiza automáticamente cuando se sincronizan nuevos torneos o eventos:

```ruby
# En SyncEventSeeds - detecta cambios automáticamente
sync_service = SyncEventSeeds.new(event)
sync_service.sync_seeds

# En SyncSmashData - con parámetro opcional
sync_service = SyncSmashData.new(update_players: true)
sync_service.sync_tournaments_and_events_atomic
```

### 2. Actualización Manual con Tareas Rake

#### Estadísticas de jugadores
```bash
rake players:stats
```

#### Actualización básica (solo jugadores que necesitan actualización)
```bash
rake players:update_from_api
```

#### Actualización en lotes (recomendado para grandes cantidades)
```bash
rake players:update_in_batches
```

#### Actualización solo de información incompleta
```bash
rake players:update_incomplete
```

#### Actualización forzada de todos los jugadores
```bash
rake players:force_update_all
```

#### Actualización de jugadores específicos
```bash
rake players:update_specific[1,2,3]
```

#### **NUEVO: Probar actualización de entrant_name**
```bash
rake players:test_entrant_name_update[player_id]
```

### 3. Actualización en Background

#### Programar actualización normal
```bash
rake players:schedule_update
```

#### Programar actualización forzada
```bash
rake players:schedule_force_update
```

### 4. Sincronización con actualización automática
```bash
rake players:sync_tournaments_with_player_update
```

## Nueva Funcionalidad: Actualización de Entrant Name

### Problema Resuelto

Anteriormente, algunos jugadores tenían `entrant_name` con formato de duplas (ej: "Bind / Braixen") porque la información se tomaba de torneos donde participaron en duplas. Ahora el sistema puede obtener el tag individual más reciente del jugador.

### Cómo Funciona

1. **Nueva Query GraphQL**: `USER_RECENT_ENTRANTS_QUERY` obtiene las participaciones recientes del usuario
2. **Filtrado Inteligente**: Busca solo participaciones individuales (un solo participante)
3. **Tag Más Reciente**: Extrae el `entrant_name` de la participación individual más reciente
4. **Actualización Automática**: Actualiza el `entrant_name` si encuentra un tag más actual

### Métodos Agregados

#### En StartGgQueries
```ruby
# Obtener tag más reciente del usuario
StartGgQueries.fetch_user_recent_tag(client, user_id)
```

#### En Player Model
```ruby
# Actualización mejorada que incluye entrant_name
player.update_from_start_gg_api

# El método ahora obtiene:
# - Información básica del usuario (nombre, bio, ubicación, etc.)
# - Tag más reciente desde participaciones individuales
# - Actualiza entrant_name si encuentra un tag más actual
```

### Ejemplo de Uso

```ruby
# Buscar jugador con problema de entrant_name
player = Player.find_by(entrant_name: "Bind / Braixen")

# Probar obtención de tag reciente
client = StartGgClient.new
recent_tag = StartGgQueries.fetch_user_recent_tag(client, player.user_id)
puts "Tag reciente: #{recent_tag}" # Debería mostrar "Braixen" en lugar de "Bind / Braixen"

# Actualizar información completa
player.update_from_start_gg_api
puts "Nuevo entrant_name: #{player.entrant_name}" # Ahora debería ser "Braixen"
```

### Tarea de Prueba

Para probar la funcionalidad con jugadores específicos:

```bash
# Probar con un jugador específico
rake players:test_entrant_name_update[123]

# Probar con múltiples jugadores
rake players:test_entrant_name_update[123,456,789]
```

Esta tarea:
1. Muestra la información actual del jugador
2. Obtiene el tag reciente desde la API
3. Compara con el entrant_name actual
4. Permite confirmar la actualización si hay cambios
5. Muestra el resultado de la actualización

## Información Actualizada

El sistema actualiza los siguientes campos desde la API de start.gg:

### Información Básica
- `name`: Nombre completo del usuario
- `entrant_name`: **NUEVO** - Tag/gamer tag más reciente desde participaciones individuales
- `discriminator`: Identificador único
- `bio`: Biografía del usuario
- `birthday`: Fecha de nacimiento

### Ubicación
- `city`: Ciudad
- `state`: Estado/región
- `country`: País

### Redes Sociales
- `twitter_handle`: Handle de Twitter

### Otros
- `gender_pronoun`/`gender_pronoum`: Pronombres de género

## Configuración de Rate Limits

### Actualización en Lotes
- **Tamaño de lote**: 20-50 jugadores
- **Pausa entre lotes**: 45-90 segundos
- **Pausa entre requests**: 1-3 segundos

### Manejo de Errores
- **Rate Limit (429)**: Pausa automática de 60 segundos y reintento
- **Errores generales**: Log detallado y continuación con siguiente jugador
- **Reintentos**: Automáticos para rate limits, manual para otros errores

## Criterios de Actualización

### Actualización Normal
Un jugador necesita actualización si:
- No tiene nombre completo (`name` vacío)
- No tiene información de ubicación (`country` vacío)
- No se ha actualizado en los últimos 30 días

### Actualización Forzada
- Actualiza todos los jugadores que tengan `user_id`
- Ignora la fecha de última actualización
- Útil para corregir información incorrecta masivamente

## Integración con Servicios Existentes

### SyncEventSeeds
```ruby
# Detecta automáticamente cambios en jugadores durante sincronización
# Actualiza si encuentra diferencias en nombre o información personal
```

### SyncSmashData
```ruby
# Parámetro opcional para actualizar jugadores de nuevos torneos
SyncSmashData.new(update_players: true)
```

### UpdatePlayersService
```ruby
# Servicio dedicado para actualizaciones masivas en lotes
service = UpdatePlayersService.new(
  batch_size: 25,
  delay_between_batches: 45.seconds,
  delay_between_requests: 2.seconds,
  force_update: false
)
results = service.update_players_in_batches
```

## Automatización con Cron

### Actualización diaria de jugadores que necesitan actualización
```bash
# Crontab entry - todos los días a las 3 AM
0 3 * * * cd /path/to/app && bundle exec rake players:update_in_batches
```

### Actualización semanal forzada
```bash
# Crontab entry - todos los domingos a las 2 AM
0 2 * * 0 cd /path/to/app && bundle exec rake players:schedule_force_update
```

### Sincronización con actualización automática
```bash
# Crontab entry - cada 6 horas
0 */6 * * * cd /path/to/app && bundle exec rake players:sync_tournaments_with_player_update
```

## Logs y Monitoreo

Todos los procesos de actualización generan logs detallados con:
- 🚀 Inicio de procesos
- 📊 Estadísticas y contadores
- ✅ Actualizaciones exitosas
- ❌ Errores y fallos
- ⏸️ Pausas por rate limits
- 🎉 Resúmenes finales

Los logs incluyen emojis para facilitar la identificación visual del estado de las operaciones. 