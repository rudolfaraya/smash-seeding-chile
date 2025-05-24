require 'rails_helper'

RSpec.describe TournamentsController, type: :request do
  describe 'GET /tournaments' do
    let!(:online_tournament) { create(:tournament, :online, name: 'Online Championship') }
    let!(:santiago_tournament) { create(:tournament, :santiago, name: 'Santiago Major') }
    let!(:valparaiso_tournament) { create(:tournament, :valparaiso, name: 'Valparaíso Weekly') }
    let!(:past_tournament) { create(:tournament, :past, name: 'Past Tournament') }

    it 'returns successful response' do
      get tournaments_path
      expect(response).to have_http_status(:success)
    end

    it 'displays all tournaments by default' do
      get tournaments_path
      expect(response.body).to include('Online Championship')
      expect(response.body).to include('Santiago Major')
      expect(response.body).to include('Valparaíso Weekly')
    end

    context 'with region filter' do
      it 'filters by Online region' do
        get tournaments_path, params: { region: 'Online' }
        expect(response.body).to include('Online Championship')
        expect(response.body).not_to include('Santiago Major')
      end

      it 'filters by Santiago region' do
        get tournaments_path, params: { region: 'Metropolitana de Santiago' }
        expect(response.body).to include('Santiago Major')
        expect(response.body).not_to include('Online Championship')
      end
    end

    context 'with city filter' do
      it 'filters by Santiago city' do
        get tournaments_path, params: { city: 'Santiago' }
        expect(response.body).to include('Santiago Major')
        expect(response.body).not_to include('Valparaíso Weekly')
      end

      it 'filters by Valparaíso city' do
        get tournaments_path, params: { city: 'Valparaíso' }
        expect(response.body).to include('Valparaíso Weekly')
        expect(response.body).not_to include('Santiago Major')
      end
    end

    context 'with search query' do
      it 'searches by tournament name' do
        get tournaments_path, params: { search: 'Championship' }
        expect(response.body).to include('Online Championship')
        expect(response.body).not_to include('Santiago Major')
      end

      it 'performs case insensitive search' do
        get tournaments_path, params: { search: 'online' }
        expect(response.body).to include('Online Championship')
      end
    end

    context 'with date filters' do
      it 'shows upcoming tournaments by default' do
        get tournaments_path
        expect(response.body).not_to include('Past Tournament')
      end

      it 'can show past tournaments' do
        get tournaments_path, params: { timeframe: 'past' }
        expect(response.body).to include('Past Tournament')
      end
    end

    context 'with pagination' do
      before do
        create_list(:tournament, 15, :santiago)
      end

      it 'paginates results' do
        get tournaments_path
        expect(response.body).to include('Anterior')
        expect(response.body).to include('Siguiente')
      end
    end
  end

  describe 'GET /tournaments/:id' do
    let(:tournament) { create(:tournament, :with_events) }

    it 'returns successful response' do
      get tournament_path(tournament)
      expect(response).to have_http_status(:success)
    end

    it 'displays tournament details' do
      get tournament_path(tournament)
      expect(response.body).to include(tournament.name)
      expect(response.body).to include(tournament.venue_address)
    end

    it 'displays tournament events' do
      event = tournament.events.first
      get tournament_path(tournament)
      expect(response.body).to include(event.name)
    end

    it 'shows start.gg link' do
      get tournament_path(tournament)
      expect(response.body).to include('Ver en Start.gg')
    end

    it 'returns 404 for non-existent tournament' do
      expect {
        get tournament_path(id: 'non-existent')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /tournaments/sync' do
    let(:tournament) { create(:tournament) }

    context 'with valid API response' do
      before do
        stub_start_gg_tournament_request(tournament.id)
        stub_start_gg_events_request(tournament.id)
      end

      it 'syncs tournaments successfully', :vcr do
        post sync_tournaments_path
        expect(response).to redirect_to(tournaments_path)
        follow_redirect!
        expect(response).to have_http_status(:success)
      end
    end

    context 'with API error' do
      before do
        stub_request(:post, "https://api.start.gg/gql/alpha")
          .to_return(status: 500, body: '{"errors": ["Server Error"]}')
      end

      it 'handles API errors gracefully', :vcr do
        post sync_tournaments_path
        expect(response).to redirect_to(tournaments_path)
        follow_redirect!
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /tournaments/:id/sync_events' do
    let(:tournament) { create(:tournament) }

    context 'with valid API response' do
      before do
        stub_start_gg_tournament_request(tournament.id)
        stub_start_gg_events_request(tournament.id)
      end

      it 'syncs events for specific tournament', :vcr do
        post sync_events_tournament_path(tournament)
        expect(response).to redirect_to(tournaments_path)
        follow_redirect!
        expect(response).to have_http_status(:success)
      end
    end

    it 'returns 404 for non-existent tournament' do
      expect {
        post sync_events_tournament_path(id: 'non-existent')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'responsive design' do
    let!(:tournament) { create(:tournament) }

    it 'works on mobile devices' do
      get tournaments_path, headers: { 
        'HTTP_USER_AGENT' => 'Mobile Safari',
        'HTTP_VIEWPORT' => 'width=375'
      }
      expect(response).to have_http_status(:success)
    end

    it 'includes responsive meta tags' do
      get tournaments_path
      expect(response.body).to include('viewport')
    end
  end

  describe 'accessibility' do
    let!(:tournament) { create(:tournament) }

    it 'includes proper semantic markup' do
      get tournaments_path
      expect(response.body).to include('<main')
      expect(response.body).to include('role=')
    end
  end
end 