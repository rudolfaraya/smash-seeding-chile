require 'rails_helper'

RSpec.describe Tournament, type: :model do
  describe 'basic functionality' do
    subject { build(:tournament) }

    it 'is valid with valid attributes' do
      expect(subject).to be_valid
    end

    it 'can be saved to database' do
      expect { subject.save! }.not_to raise_error
    end
  end

  describe 'associations' do
    it { should have_many(:events).dependent(:destroy) }
    it { should have_many(:event_seeds).through(:events) }
    it { should have_many(:players).through(:event_seeds) }
  end

  describe 'scopes' do
    let!(:online_tournament) { create(:tournament, :online) }
    let!(:physical_tournament) { create(:tournament, :santiago) }
    let!(:past_tournament) { create(:tournament, :past) }
    let!(:future_tournament) { create(:tournament, :future) }

    describe '.online_tournaments' do
      it 'returns only online tournaments' do
        expect(Tournament.online_tournaments).to include(online_tournament)
        expect(Tournament.online_tournaments).not_to include(physical_tournament)
      end
    end

    describe '.physical_tournaments' do
      it 'returns only physical tournaments' do
        expect(Tournament.physical_tournaments).to include(physical_tournament)
        expect(Tournament.physical_tournaments).not_to include(online_tournament)
      end
    end

    describe '.by_region' do
      it 'filters tournaments by region' do
        santiago_tournaments = Tournament.by_region('Metropolitana de Santiago')
        expect(santiago_tournaments).to include(physical_tournament)
        expect(santiago_tournaments).not_to include(online_tournament)
      end
    end

    describe '.by_city' do
      it 'filters tournaments by city' do
        santiago_tournaments = Tournament.by_city('Santiago')
        expect(santiago_tournaments).to include(physical_tournament)
        expect(santiago_tournaments).not_to include(online_tournament)
      end
    end

    describe '.where(start_at > Time.current)' do
      it 'returns future tournaments' do
        results = Tournament.where('start_at > ?', Time.current)
        expect(results).to include(future_tournament)
        expect(results).not_to include(past_tournament)
      end
    end

    describe '.where(start_at < Time.current)' do
      it 'returns past tournaments' do
        results = Tournament.where('start_at < ?', Time.current)
        expect(results).to include(past_tournament)
        expect(results).not_to include(future_tournament)
      end
    end
  end

  describe 'instance methods' do
    describe '#online?' do
      context 'when region is Online' do
        let(:tournament) { build(:tournament, :online) }
        
        it 'returns true' do
          expect(tournament.online?).to be true
        end
      end

      context 'when region is not Online' do
        let(:tournament) { build(:tournament, :santiago) }
        
        it 'returns false' do
          expect(tournament.online?).to be false
        end
      end
    end

    describe '#start_gg_url_or_generate' do
      let(:tournament) { build(:tournament, slug: 'test-tournament') }
      
      it 'generates correct start.gg URL' do
        expect(tournament.start_gg_url_or_generate).to eq('https://www.start.gg/test-tournament')
      end
    end

    describe '#should_be_online?' do
      context 'when venue_address indicates online' do
        let(:tournament) { build(:tournament, venue_address: 'Chile') }
        
        it 'returns true' do
          expect(tournament.should_be_online?).to be true
        end
      end

      context 'when venue_address indicates physical location' do
        let(:tournament) { build(:tournament, venue_address: 'Centro de Eventos Los Leones, Santiago') }
        
        it 'returns false' do
          expect(tournament.should_be_online?).to be false
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'location parsing' do
      context 'when venue_address changes' do
        let(:tournament) { build(:tournament, venue_address: 'Test Address') }

        it 'calls parse_location_from_venue_address' do
          expect(tournament).to receive(:parse_location_from_venue_address)
          tournament.save!
        end
      end

      context 'when venue_address is "Chile"' do
        let(:tournament) { build(:tournament, venue_address: 'Chile') }

        it 'marks tournament as online' do
          tournament.save!
          expect(tournament.region).to eq('Online')
          expect(tournament.city).to be_nil
        end
      end

      context 'when venue_address contains online keywords' do
        let(:tournament) { build(:tournament, venue_address: 'Discord', city: nil, region: nil) }

        it 'marks tournament as online' do
          tournament.save!
          expect(tournament.region).to eq('Online')
          expect(tournament.city).to be_nil
        end
      end

      context 'when venue_address contains Chilean city' do
        let(:tournament) { build(:tournament, venue_address: 'Av. Libertad 123, Santiago, Región Metropolitana') }

        it 'parses city and region correctly' do
          tournament.save!
          expect(tournament.city).to eq('Santiago')
          expect(tournament.region).to eq('Metropolitana de Santiago')
        end
      end
    end
  end

  describe 'class methods' do
    describe '.where with name search' do
      let!(:tournament1) { create(:tournament, name: 'Ultimate Championship') }
      let!(:tournament2) { create(:tournament, name: 'Smash Bros Weekly') }

      it 'finds tournaments by name using where clause' do
        results = Tournament.where("name LIKE ?", "%Ultimate%")
        expect(results).to include(tournament1)
        expect(results).not_to include(tournament2)
      end

      it 'finds tournaments case insensitive using LOWER' do
        results = Tournament.where("LOWER(name) LIKE LOWER(?)", "%ultimate%")
        expect(results).to include(tournament1)
      end
    end

    describe '.joins(:events)' do
      let!(:synced_tournament) { create(:tournament, :with_events) }
      let!(:unsynced_tournament) { create(:tournament) }

      it 'returns tournaments with events' do
        results = Tournament.joins(:events).distinct
        expect(results).to include(synced_tournament)
        expect(results).not_to include(unsynced_tournament)
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:tournament)).to be_valid
    end

    it 'creates valid online tournament' do
      tournament = create(:tournament, :online)
      expect(tournament.online?).to be true
      expect(tournament.region).to eq('Online')
    end

    it 'creates valid physical tournament' do
      tournament = create(:tournament, :santiago)
      expect(tournament.online?).to be false
      expect(tournament.city).to eq('Santiago')
      expect(tournament.region).to eq('Metropolitana de Santiago')
    end
  end
end 