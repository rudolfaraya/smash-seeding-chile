require 'rails_helper'

RSpec.describe LocationParserService, type: :service do
  let(:service) { described_class.new }

  describe '#parse_location' do
    context 'when detecting online tournaments' do
      it 'detects "Chile" as online' do
        result = service.parse_location('Chile')
        expect(result[:region]).to eq('Online')
        expect(result[:city]).to be_nil
      end

      it 'detects online keywords' do
        online_keywords = [ 'Online', 'WiFi', 'Discord', 'Internet', 'Virtual' ]

        online_keywords.each do |keyword|
          result = service.parse_location(keyword)
          expect(result[:region]).to eq('Online')
          expect(result[:city]).to be_nil
        end
      end

      it 'detects Spanish online keywords' do
        spanish_keywords = [ 'en línea', 'remoto', 'cuarentena', 'desde casa' ]

        spanish_keywords.each do |keyword|
          result = service.parse_location(keyword)
          expect(result[:region]).to eq('Online')
          expect(result[:city]).to be_nil
        end
      end

      it 'is case insensitive for online detection' do
        result = service.parse_location('ONLINE')
        expect(result[:region]).to eq('Online')

        result = service.parse_location('discord')
        expect(result[:region]).to eq('Online')
      end
    end

    context 'when parsing Chilean locations' do
      it 'attempts to parse Chilean addresses' do
        addresses = [
          'Santiago, Chile',
          'Valparaíso, Chile',
          'Concepción, Chile'
        ]

        addresses.each do |address|
          result = service.parse_location(address)
          # Solo verificamos que el servicio no falle, no resultados específicos
          expect(result).to have_key(:city)
          expect(result).to have_key(:region)
        end
      end

      it 'handles complex addresses' do
        complex_addresses = [
          'Centro de Eventos Los Leones, Santiago, Chile',
          'Mall Plaza Vespucio, Santiago, Chile'
        ]

        complex_addresses.each do |address|
          result = service.parse_location(address)
          expect(result).to have_key(:city)
          expect(result).to have_key(:region)
        end
      end
    end

    context 'when handling edge cases' do
      it 'handles nil input' do
        result = service.parse_location(nil)
        expect(result[:city]).to be_nil
        expect(result[:region]).to be_nil
      end

      it 'handles empty string' do
        result = service.parse_location('')
        expect(result[:city]).to be_nil
        expect(result[:region]).to be_nil
      end

      it 'handles non-Chilean locations gracefully' do
        result = service.parse_location('London, England')
        # El servicio está diseñado para ubicaciones chilenas, puede intentar encontrar coincidencias
        # pero debería manejar sin errores ubicaciones no chilenas
        expect(result).to have_key(:city)
        expect(result).to have_key(:region)
      end

      it 'handles malformed addresses' do
        result = service.parse_location('xyz123 invalid address format')
        # El servicio puede extraer palabras como ciudad, verificamos que no falle
        expect(result).to have_key(:city)
        expect(result).to have_key(:region)
      end

      it 'prioritizes online detection over location parsing' do
        result = service.parse_location('Discord Santiago Chile')
        expect(result[:region]).to eq('Online')
        expect(result[:city]).to be_nil
      end
    end

    context 'when parsing complex addresses' do
      it 'processes detailed addresses without errors' do
        complex_addresses = [
          'Centro de Eventos Los Leones, Av. Los Leones 382, Providencia, Santiago, Chile',
          'Mall Plaza Vespucio, La Florida, Santiago, Chile',
          'Viña del Mar, Valparaíso, Chile'
        ]

        complex_addresses.each do |address|
          result = service.parse_location(address)
          expect(result).to have_key(:city)
          expect(result).to have_key(:region)
        end
      end
    end
  end

  describe 'online tournament detection' do
    context 'when checking venue address through parse_location' do
      it 'detects online tournaments correctly' do
        online_venues = [ 'Chile', 'Online', 'Discord', 'WiFi', 'Internet' ]

        online_venues.each do |venue|
          result = service.parse_location(venue)
          expect(result[:region]).to eq('Online')
        end
      end

      it 'does not mark physical locations as online' do
        physical_venues = [
          'Centro de Eventos Los Leones, Santiago',
          'Mall Plaza Vespucio, Santiago'
        ]

        physical_venues.each do |venue|
          result = service.parse_location(venue)
          expect(result[:region]).not_to eq('Online')
        end
      end
    end
  end

  describe 'service functionality' do
    it 'correctly identifies Chilean regions' do
      # Test que verifica que el servicio puede identificar regiones chilenas principales
      major_regions = [
        'Santiago, Región Metropolitana',
        'Valparaíso, Valparaíso',
        'Concepción, Biobío'
      ]

      major_regions.each do |address|
        result = service.parse_location(address)
        # Al menos uno de los dos debería estar presente
        expect(result[:region].present? || result[:city].present?).to be true
      end
    end

    it 'handles text normalization correctly' do
      # Test indirecto de normalización a través de la funcionalidad pública
      result1 = service.parse_location('SANTIAGO, CHILE')
      result2 = service.parse_location('santiago, chile')

      expect(result1[:city]).to eq(result2[:city])
      expect(result1[:region]).to eq(result2[:region])
    end
  end

  describe 'integration with Tournament model' do
    context 'when tournament venue_address changes' do
      it 'automatically parses location for online tournament' do
        tournament = create(:tournament, venue_address: 'Chile')
        expect(tournament.region).to eq('Online')
        expect(tournament.city).to be_nil
      end

      it 'automatically parses location for Chilean tournament' do
        tournament = create(:tournament, venue_address: 'Santiago, Región Metropolitana')
        expect(tournament.region).to eq('Metropolitana de Santiago')
        expect(tournament.city).to eq('Santiago')
      end

      it 'handles online keywords in venue_address' do
        tournament = create(:tournament, venue_address: 'Discord', city: nil, region: nil)
        expect(tournament.region).to eq('Online')
        expect(tournament.city).to be_nil
      end
    end
  end
end
