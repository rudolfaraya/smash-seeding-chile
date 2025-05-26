# Testing Strategy - Smash Seeding Chile

## Filosofía de Testing

Este proyecto utiliza una estrategia de testing que **NO hace llamadas reales a APIs externas**. En su lugar, utilizamos mocks, stubs y datos simulados para garantizar que los tests sean:

- **Rápidos**: No dependen de conexiones de red
- **Confiables**: No fallan por problemas de conectividad o cambios en APIs externas
- **Determinísticos**: Siempre producen los mismos resultados
- **Aislados**: Cada test es independiente

## Estructura de Tests

```
spec/
├── factories/          # Factory Bot para generar datos de prueba
├── models/            # Tests de modelos (validaciones, asociaciones, métodos)
├── requests/          # Tests de controladores (requests HTTP)
├── services/          # Tests de servicios (lógica de negocio)
├── system/           # Tests de integración (Capybara)
├── support/          # Archivos de soporte y configuración
│   ├── api_helpers.rb    # Helpers para mockear APIs
│   └── vcr.rb           # Configuración de VCR (deshabilitado)
└── README.md         # Este archivo
```

## Mocking de APIs Externas

### Start.gg API

Para la API de Start.gg, utilizamos los siguientes helpers en `spec/support/api_helpers.rb`:

```ruby
# Mockear respuesta de torneos
stub_start_gg_tournaments_query(custom_data)

# Mockear respuesta de eventos
stub_start_gg_events_request(tournament_id, custom_events)

# Mockear respuesta de seeds
stub_start_gg_seeds_request(event_id, custom_seeds)

# Mockear errores de API
stub_start_gg_api_error(status: 500, error_message: "Server Error")

# Mockear rate limiting
stub_start_gg_rate_limit
```

### Servicios de Sincronización

Los servicios que interactúan con APIs externas se mockean usando `instance_double`:

```ruby
# Mock del servicio SyncSmashData
mock_sync_service = mock_sync_smash_data_service(return_value: 5)

# Mock del servicio SyncNewTournaments  
mock_sync_service = mock_sync_new_tournaments_service(return_value: 3)

# Mock del servicio SyncTournamentEvents
mock_sync_service = mock_sync_tournament_events_service(tournament, return_value: 2)
```

## Configuración de WebMock y VCR

### WebMock
- **Deshabilita todas las conexiones HTTP reales** por defecto
- Permite conexiones a localhost para tests de sistema
- Se resetea después de cada test

### VCR
- Configurado en modo `record: :none` para evitar grabaciones accidentales
- Solo permite grabación con `VCR_RECORD_MODE=true`
- Filtra datos sensibles como tokens de API

## Ejemplos de Tests

### Test de Controlador con Mock

```ruby
describe 'POST /tournaments/sync' do
  context 'with valid API response' do
    before do
      # Mock del servicio
      sync_service = instance_double(SyncSmashData)
      allow(SyncSmashData).to receive(:new).and_return(sync_service)
      allow(sync_service).to receive(:call).and_return(5)
      
      # Stub de la API
      stub_start_gg_tournaments_query
    end

    it 'syncs tournaments successfully' do
      post sync_tournaments_path
      expect(response).to redirect_to(tournaments_path)
    end
  end
end
```

### Test de Servicio con Mock

```ruby
describe SyncSmashData do
  let(:mock_client) { instance_double(StartGgClient) }

  before do
    allow(StartGgClient).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:query).and_return(mock_response)
  end

  it 'creates tournaments from API data' do
    expect { service.call }.to change(Tournament, :count).by(2)
  end
end
```

### Test de Modelo con Mock

```ruby
describe Event do
  describe '#fetch_and_save_seeds' do
    let(:mock_sync_service) { instance_double(SyncEventSeeds) }

    before do
      allow(SyncEventSeeds).to receive(:new).and_return(mock_sync_service)
      allow(mock_sync_service).to receive(:call).and_return(5)
    end

    it 'calls the sync service' do
      expect(mock_sync_service).to receive(:call).with(event)
      event.fetch_and_save_seeds
    end
  end
end
```

## Ejecutar Tests

```bash
# Ejecutar todos los tests
bundle exec rspec

# Ejecutar tests específicos
bundle exec rspec spec/models/
bundle exec rspec spec/requests/tournaments_spec.rb
bundle exec rspec spec/services/

# Ejecutar con coverage
bundle exec rspec --format documentation

# Verificar que no hay llamadas HTTP reales
bundle exec rspec --fail-fast
```

## Datos de Prueba

### Factories
Utilizamos Factory Bot para generar datos de prueba consistentes:

```ruby
# Crear un torneo de prueba
tournament = create(:tournament, :santiago)

# Crear un evento con seeds
event = create(:event, :with_seeds)

# Crear un jugador
player = create(:player, :with_characters)
```

### Datos Mock de API
Los datos simulados de la API están en `spec/support/api_helpers.rb` y incluyen:

- Respuestas de torneos con datos realistas
- Respuestas de eventos con participantes
- Respuestas de seeds con información de jugadores
- Respuestas de error para casos edge

## Beneficios de Esta Estrategia

1. **Velocidad**: Los tests corren en segundos, no minutos
2. **Confiabilidad**: No dependen de servicios externos
3. **Cobertura**: Podemos probar casos edge y errores fácilmente
4. **Mantenimiento**: Cambios en APIs externas no rompen tests
5. **Desarrollo Offline**: Los tests funcionan sin conexión a internet

## Consideraciones

- **Tests de Integración Real**: Para validar la integración real con Start.gg, se pueden crear tests separados que se ejecuten manualmente o en CI con datos reales
- **Actualización de Mocks**: Los datos mock deben actualizarse si cambia la estructura de la API
- **Validación de Contratos**: Considerar usar herramientas como Pact para validar contratos de API

## Troubleshooting

### Error: "Real HTTP connections are disabled"
Esto significa que un test está intentando hacer una llamada HTTP real. Solución:
1. Agregar el stub apropiado en el test
2. Verificar que el mock del servicio esté configurado correctamente

### Error: "VCR cassette recording detected"
Esto significa que VCR está intentando grabar una nueva cassette. Solución:
1. Usar mocks en lugar de VCR
2. Si necesitas grabar: `VCR_RECORD_MODE=true bundle exec rspec`

### Tests lentos
Si los tests son lentos, verificar:
1. Que no haya llamadas HTTP reales
2. Que los mocks estén configurados correctamente
3. Que no haya `sleep` o `retry` en los tests 