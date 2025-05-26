module ApiHelpers
  # Stub Start.gg API responses
  def stub_start_gg_tournament_request(tournament_id, response_data = nil)
    response_data ||= mock_tournament_data(tournament_id)
    
    stub_request(:post, "https://api.start.gg/gql/alpha")
      .with(
        body: hash_including("query" => /tournament.*#{tournament_id}/),
        headers: {
          'Authorization' => "Bearer #{ENV['START_GG_API_TOKEN'] || 'test_token'}",
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: response_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_start_gg_events_request(tournament_id, events_data = nil)
    events_data ||= mock_events_data(tournament_id)
    
    stub_request(:post, "https://api.start.gg/gql/alpha")
      .with(
        body: hash_including("query" => /events.*#{tournament_id}/),
        headers: {
          'Authorization' => "Bearer #{ENV['START_GG_API_TOKEN'] || 'test_token'}",
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: events_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
  
  def stub_start_gg_seeds_request(event_id, seeds_data = nil)
    seeds_data ||= mock_seeds_data(event_id)
    
    stub_request(:post, "https://api.start.gg/gql/alpha")
      .with(
        body: hash_including("query" => /seeds.*#{event_id}/),
        headers: {
          'Authorization' => "Bearer #{ENV['START_GG_API_TOKEN'] || 'test_token'}",
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: seeds_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub para consultas de torneos generales
  def stub_start_gg_tournaments_query(tournaments_data = nil)
    tournaments_data ||= mock_tournaments_list_data
    
    stub_request(:post, "https://api.start.gg/gql/alpha")
      .with(
        body: hash_including("query" => /TournamentsInChile/),
        headers: {
          'Authorization' => "Bearer #{ENV['START_GG_API_TOKEN'] || 'test_token'}",
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: tournaments_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub para consultas de torneos desde una fecha específica
  def stub_start_gg_tournaments_since_date_query(tournaments_data = nil)
    tournaments_data ||= mock_tournaments_list_data
    
    stub_request(:post, "https://api.start.gg/gql/alpha")
      .with(
        body: hash_including("query" => /TournamentsInChileSinceDate/),
        headers: {
          'Authorization' => "Bearer #{ENV['START_GG_API_TOKEN'] || 'test_token'}",
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: tournaments_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub para errores de API
  def stub_start_gg_api_error(status = 500, error_message = "Server Error")
    stub_request(:post, "https://api.start.gg/gql/alpha")
      .to_return(
        status: status,
        body: { "errors" => [error_message] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub para rate limiting
  def stub_start_gg_rate_limit
    stub_request(:post, "https://api.start.gg/gql/alpha")
      .to_return(
        status: 429,
        body: { "errors" => ["Rate limit exceeded"] }.to_json,
        headers: { 
          'Content-Type' => 'application/json',
          'Retry-After' => '60'
        }
      )
  end

  # Mock de servicios
  def mock_sync_smash_data_service(return_value = 5)
    sync_service = instance_double(SyncSmashData)
    allow(SyncSmashData).to receive(:new).and_return(sync_service)
    allow(sync_service).to receive(:call).and_return(return_value)
    sync_service
  end

  def mock_sync_new_tournaments_service(return_value = 3)
    sync_service = instance_double(SyncNewTournaments)
    allow(SyncNewTournaments).to receive(:new).and_return(sync_service)
    allow(sync_service).to receive(:call).and_return(return_value)
    sync_service
  end

  def mock_sync_tournament_events_service(tournament, return_value = 2)
    sync_service = instance_double(SyncTournamentEvents)
    allow(SyncTournamentEvents).to receive(:new).and_return(sync_service)
    allow(sync_service).to receive(:call).with(tournament).and_return(return_value)
    sync_service
  end

  def mock_sync_event_seeds_service(event, return_value = 10)
    sync_service = instance_double(SyncEventSeeds)
    allow(SyncEventSeeds).to receive(:new).and_return(sync_service)
    allow(sync_service).to receive(:call).with(event).and_return(return_value)
    sync_service
  end
  
  private
  
  def mock_tournament_data(tournament_id)
    {
      "data" => {
        "tournament" => {
          "id" => tournament_id,
          "name" => "Test Tournament #{tournament_id}",
          "slug" => "test-tournament-#{tournament_id}",
          "startAt" => 1.week.from_now.to_i,
          "endAt" => (1.week.from_now + 1.day).to_i,
          "venueAddress" => "Santiago, Región Metropolitana, Chile",
          "numAttendees" => 64,
          "events" => [
            {
              "id" => "#{tournament_id}001",
              "name" => "Super Smash Bros. Ultimate Singles",
              "slug" => "ultimate-singles"
            }
          ]
        }
      }
    }
  end
  
  def mock_events_data(tournament_id)
    {
      "data" => {
        "tournament" => {
          "id" => tournament_id,
          "name" => "Test Tournament #{tournament_id}",
          "events" => [
            {
              "id" => "#{tournament_id}001",
              "name" => "Super Smash Bros. Ultimate Singles",
              "slug" => "ultimate-singles",
              "numEntrants" => 32,
              "videogame" => {
                "id" => 1386,
                "name" => "Super Smash Bros. Ultimate"
              }
            },
            {
              "id" => "#{tournament_id}002", 
              "name" => "Super Smash Bros. Ultimate Doubles",
              "slug" => "ultimate-doubles",
              "numEntrants" => 16,
              "videogame" => {
                "id" => 1386,
                "name" => "Super Smash Bros. Ultimate"
              }
            }
          ]
        }
      }
    }
  end
  
  def mock_seeds_data(event_id)
    {
      "data" => {
        "tournament" => {
          "events" => [
            {
              "id" => event_id,
              "entrants" => {
                "nodes" => [
                  {
                    "id" => "#{event_id}1",
                    "name" => "TestPlayer1",
                    "initialSeedNum" => 1,
                    "participants" => [
                      {
                        "player" => {
                          "id" => 1001,
                          "user" => {
                            "id" => 1001,
                            "slug" => "user/testplayer1",
                            "name" => "Test Player 1",
                            "discriminator" => "1234",
                            "bio" => "Test bio",
                            "birthday" => nil,
                            "genderPronoun" => nil,
                            "location" => {
                              "city" => "Santiago",
                              "state" => "Región Metropolitana",
                              "country" => "Chile"
                            },
                            "authorizations" => []
                          }
                        }
                      }
                    ]
                  },
                  {
                    "id" => "#{event_id}2",
                    "name" => "TestPlayer2",
                    "initialSeedNum" => 2,
                    "participants" => [
                      {
                        "player" => {
                          "id" => 1002,
                          "user" => {
                            "id" => 1002,
                            "slug" => "user/testplayer2",
                            "name" => "Test Player 2",
                            "discriminator" => "5678",
                            "bio" => "Another test bio",
                            "birthday" => nil,
                            "genderPronoun" => nil,
                            "location" => {
                              "city" => "Valparaíso",
                              "state" => "Valparaíso",
                              "country" => "Chile"
                            },
                            "authorizations" => []
                          }
                        }
                      }
                    ]
                  }
                ]
              }
            }
          ]
        }
      }
    }
  end

  def mock_tournaments_list_data
    {
      "data" => {
        "tournaments" => {
          "nodes" => [
            {
              "id" => 123456,
              "name" => "Test Tournament 1",
              "slug" => "test-tournament-1",
              "startAt" => 1.week.from_now.to_i,
              "endAt" => (1.week.from_now + 1.day).to_i,
              "venueAddress" => "Santiago, Región Metropolitana, Chile",
              "numAttendees" => 64
            },
            {
              "id" => 123457,
              "name" => "Test Tournament 2",
              "slug" => "test-tournament-2",
              "startAt" => 2.weeks.from_now.to_i,
              "endAt" => (2.weeks.from_now + 1.day).to_i,
              "venueAddress" => "Valparaíso, Valparaíso, Chile",
              "numAttendees" => 32
            }
          ],
          "pageInfo" => {
            "total" => 2,
            "totalPages" => 1
          }
        }
      }
    }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers
  
  # Configuración para deshabilitar conexiones HTTP reales en tests
  config.before(:each) do
    # Deshabilitar todas las conexiones HTTP reales
    WebMock.disable_net_connect!(allow_localhost: true)
  end
  
  config.after(:each) do
    # Limpiar todos los stubs después de cada test
    WebMock.reset!
  end
end 