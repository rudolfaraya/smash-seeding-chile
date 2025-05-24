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
  
  private
  
  def mock_tournament_data(tournament_id)
    {
      "data" => {
        "tournament" => {
          "id" => tournament_id,
          "name" => "Test Tournament",
          "slug" => "test-tournament-#{tournament_id}",
          "startAt" => 1.week.from_now.to_i,
          "venueAddress" => "Santiago, Región Metropolitana, Chile",
          "events" => [
            {
              "id" => "#{tournament_id}001",
              "name" => "Super Smash Bros. Ultimate Singles"
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
                            "discriminator" => "1234"
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
                            "discriminator" => "5678"
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
end

RSpec.configure do |config|
  config.include ApiHelpers
end 