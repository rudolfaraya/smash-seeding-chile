# Configuración Automática de Torneos Online para venue_address: "Chile"

## Resumen

Se ha implementado una funcionalidad para que todos los torneos que tengan `venue_address: "Chile"` se marquen automáticamente como online, tanto los existentes como los futuros.

## Cambios Implementados

### 1. Modificación del LocationParserService

**Archivo:** `app/services/location_parser_service.rb`

Se agregó `'chile'` a las palabras clave que indican torneos online:

```ruby
venue_keywords: [
  'online', 'wifi', 'discord', 'internet', 'virtual', 'remoto',
  'en línea', 'en linea', 'desde casa', 'digital', 'netplay',
  'quarantine', 'cuarentena', 'lockdown', 'stay home', 'quedateencasa',
  'home', 'casa', 'anywhere', 'cualquier lugar', 'worldwide', 'global',
  'chile'  # Agregar 'chile' como indicador de torneo online
]
```

### 2. Callback en el Modelo Tournament

**Archivo:** `app/models/tournament.rb`

Se agregó un callback que se ejecuta automáticamente cuando se crea o actualiza un torneo:

```ruby
# Callback para marcar como online si venue_address es "Chile"
before_save :mark_chile_as_online, if: :venue_address_changed?

private

def mark_chile_as_online
  if venue_address == 'Chile'
    self.city = nil
    self.region = 'Online'
    Rails.logger.info "Torneo #{name} marcado automáticamente como online (venue_address: 'Chile')"
  end
end
```

### 3. Tarea Rake para Torneos Existentes

**Archivo:** `lib/tasks/mark_chile_online.rake`

Se crearon tareas rake para gestionar los torneos con `venue_address: "Chile"`:

- `tournaments:mark_chile_as_online` - Marca como online todos los torneos existentes
- `tournaments:show_chile_tournaments` - Muestra información de torneos con venue_address "Chile"

## Ejecución

### Para Torneos Existentes

```bash
# Marcar todos los torneos existentes con venue_address: "Chile" como online
bin/rails tournaments:mark_chile_as_online

# Ver información de torneos con venue_address: "Chile"
bin/rails tournaments:show_chile_tournaments
```

### Para Torneos Futuros

Los nuevos torneos que se creen o actualicen con `venue_address: "Chile"` se marcarán automáticamente como online gracias al callback implementado.

## Resultados

### Estadísticas Actuales

- **Total de torneos procesados:** 109
- **Todos marcados como online:** ✅ 100%
- **Porcentaje de torneos online en la aplicación:** 7.7% (113 de 1472)

### Verificación Automática

Ambos sistemas trabajan en conjunto:

1. **Callback del modelo:** Se ejecuta en tiempo real cuando se guarda un torneo
2. **LocationParserService:** Detecta "Chile" como palabra clave para torneos online

## Testing

La funcionalidad se ha verificado manualmente:

```ruby
# Crear un nuevo torneo con venue_address: "Chile"
t = Tournament.new(name: 'Test', venue_address: 'Chile', start_at: 1.day.from_now)
t.save!
# => region: "Online", online?: true
```

## Logs

Los cambios automáticos se registran en los logs:

```
Torneo [NOMBRE] marcado automáticamente como online (venue_address: 'Chile')
```

---

**Fecha de implementación:** Enero 2025  
**Desarrollador:** Sistema de seeding de Smash Chile 