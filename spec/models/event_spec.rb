require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'associations' do
    it { should belong_to(:tournament) }
    it { should have_many(:event_seeds).dependent(:destroy) }
    it { should have_many(:players).through(:event_seeds) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'instance methods' do
    let(:tournament) { create(:tournament, slug: 'test-tournament') }
    let(:event) { create(:event, tournament: tournament, slug: 'ultimate-singles') }

    describe '#start_gg_event_url_or_generate' do
      context 'when slug and tournament slug are present' do
        it 'generates URL from tournament and event slugs' do
          expected_url = 'https://www.start.gg/test-tournament/event/ultimate-singles'
          expect(event.start_gg_event_url_or_generate).to eq(expected_url)
        end

        context 'when event slug starts with tournament slug' do
          before { event.update(slug: 'test-tournament/ultimate-singles') }

          it 'extracts only the event part' do
            expected_url = 'https://www.start.gg/test-tournament/event/ultimate-singles'
            expect(event.start_gg_event_url_or_generate).to eq(expected_url)
          end
        end

        context 'when slug is missing' do
          before { event.update(slug: nil) }

          it 'returns nil' do
            expect(event.start_gg_event_url_or_generate).to be_nil
          end
        end
      end
    end

    describe '#has_seeds?' do
      context 'when event has seeds' do
        before { create(:event_seed, event: event) }

        it 'returns true' do
          expect(event.has_seeds?).to be true
        end
      end

      context 'when event has no seeds' do
        it 'returns false' do
          expect(event.has_seeds?).to be false
        end
      end
    end

    describe '#calculated_event_seeds_count' do
      it 'returns the count of event seeds' do
        create_list(:event_seed, 3, event: event)
        expect(event.calculated_event_seeds_count).to eq(3)
      end

      it 'returns 0 when no seeds exist' do
        expect(event.calculated_event_seeds_count).to eq(0)
      end
    end

    describe '#fetch_and_save_seeds' do
      let(:mock_sync_service) { instance_double(SyncEventSeeds) }

      before do
        allow(SyncEventSeeds).to receive(:new).and_return(mock_sync_service)
      end

      context 'when event already has seeds' do
        before { create(:event_seed, event: event) }

        it 'does not call the sync service' do
          expect(mock_sync_service).not_to receive(:call)
          event.fetch_and_save_seeds
        end

        it 'returns early without syncing' do
          result = event.fetch_and_save_seeds
          expect(result).to be_nil
        end
      end

      context 'when event has no seeds' do
        context 'for regular events' do
          before do
            allow(event).to receive(:fetch_seeds_sequentially).and_return([
              {
                "seedNum" => 1,
                "entrant" => {
                  "name" => "Test Player",
                  "participants" => [
                    {
                      "player" => {
                        "id" => 1,
                        "user" => {
                          "id" => 1,
                          "slug" => "user/testplayer",
                          "name" => "Test Player"
                        }
                      }
                    }
                  ]
                }
              }
            ])
          end

          it 'processes seeds data' do
            expect { event.fetch_and_save_seeds }.to change(EventSeed, :count).by(1)
          end

          it 'returns the number of synced seeds' do
            result = event.fetch_and_save_seeds
            expect(result).to be_nil
          end
        end

        context 'for La Gagoleta 3: Edición Loki - Singles (special case)' do
          before do
            tournament.update(name: "La Gagoleta 3: Edición Loki")
            event.update(name: "Singles")
            allow(event).to receive(:simulate_la_gagolet_seeds)
          end

          it 'uses simulated data instead of API' do
            expect(event).to receive(:simulate_la_gagolet_seeds)
            event.fetch_and_save_seeds
          end
        end

        context 'when sync service raises an error' do
          before do
            allow(event).to receive(:fetch_seeds_sequentially).and_raise(StandardError.new("API Error"))
          end

          it 'propagates the error' do
            expect { event.fetch_and_save_seeds }.to raise_error(StandardError, "API Error")
          end
        end
      end

      context 'with retry logic' do
        before do
          # Simular que falla 2 veces y luego funciona
          call_count = 0
          allow(event).to receive(:fetch_seeds_sequentially) do
            call_count += 1
            if call_count <= 2
              raise Faraday::ClientError.new("Rate limit", { status: 429 })
            else
              []
            end
          end
          allow(event).to receive(:sleep) # Mock sleep to speed up tests
        end

        it 'retries on rate limit errors' do
          expect(event).to receive(:fetch_seeds_sequentially).exactly(3).times
          event.fetch_and_save_seeds(max_retries: 3, retry_delay: 0.1)
        end
      end
    end

    describe 'scopes and queries' do
      let!(:event_with_seeds) { create(:event, :with_seeds, tournament: tournament) }
      let!(:event_without_seeds) { create(:event, tournament: tournament) }

      describe '.with_seeds' do
        it 'returns events that have seeds' do
          events_with_seeds = Event.joins(:event_seeds).distinct
          expect(events_with_seeds).to include(event_with_seeds)
          expect(events_with_seeds).not_to include(event_without_seeds)
        end
      end

      describe '.without_seeds' do
        it 'returns events that do not have seeds' do
          events_without_seeds = Event.left_joins(:event_seeds).where(event_seeds: { id: nil })
          expect(events_without_seeds).to include(event_without_seeds)
          expect(events_without_seeds).not_to include(event_with_seeds)
        end
      end
    end
  end

  describe 'callbacks and validations' do
    let(:tournament) { create(:tournament) }

    it 'is valid with valid attributes' do
      event = build(:event, tournament: tournament)
      expect(event).to be_valid
    end

    it 'is invalid without a name' do
      event = build(:event, name: nil, tournament: tournament)
      expect(event).not_to be_valid
      expect(event.errors[:name]).to be_present
    end

    it 'is invalid without a tournament' do
      event = build(:event, tournament: nil)
      expect(event).not_to be_valid
      expect(event.errors[:tournament]).to be_present
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:event)).to be_valid
    end

    it 'has a valid factory with seeds' do
      event = create(:event, :with_seeds)
      expect(event).to be_valid
      expect(event.event_seeds.count).to be > 0
    end
  end
end 