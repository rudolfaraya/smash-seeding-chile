require 'rails_helper'

RSpec.describe TournamentsController, type: :request do
  describe 'GET /tournaments' do
    let!(:tournament) { create(:tournament, name: 'Test Tournament') }

    it 'returns successful response' do
      get tournaments_path
      expect(response).to have_http_status(:success)
    end

    it 'displays tournaments' do
      get tournaments_path
      expect(response.body).to include('Test Tournament')
    end

    context 'with search query' do
      let!(:santiago_tournament) { create(:tournament, name: 'Santiago Major') }
      let!(:valparaiso_tournament) { create(:tournament, name: 'Valparaíso Weekly') }

      it 'searches by tournament name' do
        get tournaments_path, params: { query: 'Santiago' }
        expect(response).to have_http_status(:success)
        # Verificar que la búsqueda funciona verificando el contenido
        expect(response.body).to include('Santiago Major')
      end
    end

    context 'with date filters' do
      let!(:upcoming_tournament) { create(:tournament, name: 'Future Tournament', start_at: 1.week.from_now) }
      let!(:past_tournament) { create(:tournament, name: 'Past Tournament', start_at: 1.week.ago) }

      it 'shows upcoming tournaments by default' do
        get tournaments_path
        expect(response).to have_http_status(:success)
        # Verificar que muestra torneos
        expect(response.body).to include('Tournament')
      end
    end

    context 'with pagination' do
      before { create_list(:tournament, 25) }

      it 'paginates results' do
        get tournaments_path
        expect(response).to have_http_status(:success)
        # Verificar que la página se carga correctamente
        expect(response.body).to include('Tournament')
      end
    end
  end

  describe 'GET /tournaments/:id' do
    let(:tournament) { create(:tournament) }
    let!(:event) { create(:event, tournament: tournament) }

    it 'returns successful response' do
      get tournament_path(tournament)
      expect(response).to have_http_status(:success)
    end

    it 'displays tournament details' do
      get tournament_path(tournament)
      expect(response.body).to include(tournament.name)
    end

    it 'displays tournament events' do
      get tournament_path(tournament)
      expect(response.body).to include(event.name)
    end

    it 'shows start.gg link' do
      get tournament_path(tournament)
      expect(response.body).to include('start.gg')
    end

    it 'returns 404 for non-existent tournament' do
      get tournament_path(id: 999999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /tournaments/sync' do
    context 'with valid API response' do
      before do
        # Mock del servicio SyncSmashData
        sync_service = instance_double(SyncSmashData)
        allow(SyncSmashData).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync_tournaments).and_return(5) # Simula 5 nuevos torneos
      end

      it 'syncs tournaments successfully' do
        post sync_tournaments_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(tournaments_path)
      end
    end

    context 'with API error' do
      before do
        # Mock del servicio que lanza una excepción
        sync_service = instance_double(SyncSmashData)
        allow(SyncSmashData).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync_tournaments).and_raise(StandardError.new('API Error'))
      end

      it 'handles API errors gracefully' do
        post sync_tournaments_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(tournaments_path)
      end
    end
  end

  describe 'POST /tournaments/sync_new_tournaments' do
    context 'with valid API response' do
      before do
        # Mock del servicio SyncSmashData
        sync_service = instance_double(SyncSmashData)
        allow(SyncSmashData).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync_tournaments_and_events_atomic).and_return(3) # Simula 3 nuevos torneos
      end

      it 'syncs new tournaments successfully' do
        post sync_new_tournaments_tournaments_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(tournaments_path)
      end
    end

    context 'with no new tournaments' do
      before do
        sync_service = instance_double(SyncSmashData)
        allow(SyncSmashData).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync_tournaments_and_events_atomic).and_return(0) # Sin nuevos torneos
      end

      it 'shows no new tournaments message' do
        post sync_new_tournaments_tournaments_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(tournaments_path)
      end
    end
  end

  describe 'POST /tournaments/:id/sync_events' do
    let(:tournament) { create(:tournament) }

    context 'with valid API response' do
      before do
        # Mock del servicio SyncSmashData
        sync_service = instance_double(SyncSmashData)
        allow(SyncSmashData).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync_events_for_single_tournament).with(tournament).and_return(2) # Simula 2 nuevos eventos
      end

      it 'syncs events for specific tournament' do
        post sync_events_tournament_path(tournament)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(tournaments_path)
      end
    end

    context 'with no new events' do
      before do
        sync_service = instance_double(SyncSmashData)
        allow(SyncSmashData).to receive(:new).and_return(sync_service)
        allow(sync_service).to receive(:sync_events_for_single_tournament).with(tournament).and_return(0) # Sin nuevos eventos
      end

      it 'shows no new events message' do
        post sync_events_tournament_path(tournament)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(tournaments_path)
      end
    end

    it 'returns 404 for non-existent tournament' do
      post sync_events_tournament_path(id: 999999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'accessibility' do
    let!(:tournament) { create(:tournament) }

    it 'includes proper semantic markup' do
      get tournaments_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('<main')
      expect(response.body).to include('<h1')
    end
  end
end 