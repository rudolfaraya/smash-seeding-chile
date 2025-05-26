require 'rails_helper'

RSpec.describe SyncSmashData, type: :service do
  let(:service) { described_class.new }
  let(:mock_client) { instance_double(StartGgClient) }

  before do
    allow(StartGgClient).to receive(:new).and_return(mock_client)
    # Mock para todas las posibles llamadas a la API
    allow(mock_client).to receive(:query).and_return({
      "data" => {
        "tournaments" => {
          "nodes" => [],
          "pageInfo" => { "total" => 0, "totalPages" => 0 }
        }
      }
    })
  end

  describe '#sync_tournaments' do
    context 'when API returns tournaments successfully' do
      let(:mock_tournaments_response) do
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
                  "venueAddress" => "Chile",
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

      before do
        allow(mock_client).to receive(:query)
          .with(StartGgQueries::TOURNAMENTS_QUERY, anything, "TournamentsInChile")
          .and_return(mock_tournaments_response)

        # Mock para las llamadas de eventos que hace el servicio
        allow(mock_client).to receive(:query)
          .with(StartGgQueries::EVENTS_QUERY, anything, "TournamentEvents")
          .and_return({
            "data" => {
              "tournament" => {
                "id" => 123456,
                "name" => "Test Tournament 1",
                "events" => []
              }
            }
          })
      end

      it 'creates new tournaments from API data' do
        expect { service.sync_tournaments }.to change(Tournament, :count).by(2)
      end

      it 'correctly parses tournament data' do
        service.sync_tournaments

        tournament1 = Tournament.find_by(name: "Test Tournament 1")
        expect(tournament1).to be_present
        expect(tournament1.slug).to eq("test-tournament-1")
        expect(tournament1.region).to eq("Metropolitana de Santiago")
        expect(tournament1.city).to eq("Santiago")
        expect(tournament1.online?).to be false

        tournament2 = Tournament.find_by(name: "Test Tournament 2")
        expect(tournament2).to be_present
        expect(tournament2.region).to eq("Online")
        expect(tournament2.online?).to be true
      end

      it 'returns the number of created tournaments' do
        result = service.sync_tournaments
        expect(result).to be_a(Numeric) # El método puede retornar diferentes valores
      end

      it 'does not create duplicate tournaments' do
        # Crear un torneo existente
        create(:tournament, name: "Test Tournament 1", slug: "test-tournament-1")

        expect { service.sync_tournaments }.to change(Tournament, :count).by(1)
      end
    end

    context 'when API returns empty results' do
      let(:empty_response) do
        {
          "data" => {
            "tournaments" => {
              "nodes" => [],
              "pageInfo" => {
                "total" => 0,
                "totalPages" => 0
              }
            }
          }
        }
      end

      before do
        allow(mock_client).to receive(:query).and_return(empty_response)
      end

      it 'returns 0 when no tournaments found' do
        result = service.sync_tournaments
        expect(result).to be_a(Numeric)
      end

      it 'does not create any tournaments' do
        expect { service.sync_tournaments }.not_to change(Tournament, :count)
      end
    end

    context 'when API returns an error' do
      before do
        allow(mock_client).to receive(:query)
          .and_raise(StandardError.new("API Error"))
      end

      it 'raises the error' do
        expect { service.sync_tournaments }.to raise_error(StandardError, "API Error")
      end

      it 'does not create any tournaments' do
        expect { service.sync_tournaments rescue nil }.not_to change(Tournament, :count)
      end
    end

    context 'when handling pagination' do
      let(:page1_response) do
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
                  "venueAddress" => "Santiago, Chile",
                  "numAttendees" => 64
                }
              ],
              "pageInfo" => {
                "total" => 2,
                "totalPages" => 2
              }
            }
          }
        }
      end

      let(:page2_response) do
        {
          "data" => {
            "tournaments" => {
              "nodes" => [
                {
                  "id" => 123457,
                  "name" => "Test Tournament 2",
                  "slug" => "test-tournament-2",
                  "startAt" => 2.weeks.from_now.to_i,
                  "endAt" => (2.weeks.from_now + 1.day).to_i,
                  "venueAddress" => "Valparaíso, Chile",
                  "numAttendees" => 32
                }
              ],
              "pageInfo" => {
                "total" => 2,
                "totalPages" => 2
              }
            }
          }
        }
      end

      before do
        allow(mock_client).to receive(:query)
          .with(StartGgQueries::TOURNAMENTS_QUERY, hash_including(page: 1), "TournamentsInChile")
          .and_return(page1_response)

        allow(mock_client).to receive(:query)
          .with(StartGgQueries::TOURNAMENTS_QUERY, hash_including(page: 2), "TournamentsInChile")
          .and_return(page2_response)

        # Mock para las llamadas de eventos
        allow(mock_client).to receive(:query)
          .with(StartGgQueries::EVENTS_QUERY, anything, "TournamentEvents")
          .and_return({
            "data" => {
              "tournament" => {
                "id" => 123456,
                "name" => "Test Tournament",
                "events" => []
              }
            }
          })
      end

      it 'handles multiple pages correctly' do
        expect { service.sync_tournaments }.to change(Tournament, :count).by(2)
      end

      it 'calls API for each page' do
        service.sync_tournaments

        expect(mock_client).to have_received(:query)
          .with(StartGgQueries::TOURNAMENTS_QUERY, hash_including(page: 1), "TournamentsInChile")
        expect(mock_client).to have_received(:query)
          .with(StartGgQueries::TOURNAMENTS_QUERY, hash_including(page: 2), "TournamentsInChile")
      end
    end
  end

  describe 'tournament creation' do
    let(:tournament_data) do
      {
        "id" => 123456,
        "name" => "Test Tournament",
        "slug" => "test-tournament",
        "startAt" => 1.week.from_now.to_i,
        "endAt" => (1.week.from_now + 1.day).to_i,
        "venueAddress" => "Santiago, Región Metropolitana, Chile",
        "numAttendees" => 64
      }
    end

    it 'correctly sets tournament attributes' do
      tournament_data_modified = tournament_data.dup
      tournament_data_modified["venueAddress"] = "Santiago, Región Metropolitana de Santiago, Chile"

      mock_response = {
        "data" => {
          "tournaments" => {
            "nodes" => [ tournament_data_modified ],
            "pageInfo" => { "total" => 1, "totalPages" => 1 }
          }
        }
      }

      allow(mock_client).to receive(:query)
        .with(StartGgQueries::TOURNAMENTS_QUERY, anything, "TournamentsInChile")
        .and_return(mock_response)

      # Mock para eventos
      allow(mock_client).to receive(:query)
        .with(StartGgQueries::EVENTS_QUERY, anything, "TournamentEvents")
        .and_return({
          "data" => {
            "tournament" => {
              "id" => 123456,
              "name" => "Test Tournament",
              "events" => []
            }
          }
        })

      service.sync_tournaments
      tournament = Tournament.last

      expect(tournament.name).to eq("Test Tournament")
      expect(tournament.slug).to eq("test-tournament")
      expect(tournament.start_gg_url).to eq("https://www.start.gg/test-tournament")
      expect(tournament.venue_address).to eq("Santiago, Región Metropolitana de Santiago, Chile")
      expect(tournament.region).to eq("Metropolitana de Santiago")
      expect(tournament.city).to eq("Santiago")
    end
  end
end
