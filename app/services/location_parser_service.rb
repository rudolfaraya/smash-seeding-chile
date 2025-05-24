class LocationParserService
  def initialize
    @regions_data = load_regions_data
    @commune_to_region_map = build_commune_to_region_map
    @online_keywords = build_online_keywords
  end

  def parse_location(venue_address)
    return { city: nil, region: nil } if venue_address.blank?

    # Verificar si es un torneo online antes de procesar ubicación física
    if online_tournament?(venue_address)
      return { city: nil, region: "Online" }
    end

    # Limpiar y normalizar el texto
    normalized_address = normalize_text(venue_address)
    
    # Buscar comuna/ciudad
    city = extract_city(normalized_address)
    
    # Buscar región
    region = extract_region(normalized_address, city)
    
    { city: city, region: region }
  end

  def parse_and_update_tournament(tournament)
    return if tournament.venue_address.blank?
    
    location_data = parse_location(tournament.venue_address)
    
    tournament.update_columns(
      city: location_data[:city],
      region: location_data[:region]
    )
    
    location_data
  end

  def parse_all_tournaments
    updated_count = 0
    
    Tournament.where('venue_address IS NOT NULL AND venue_address != ?', '').find_each do |tournament|
      if tournament.city.blank? || tournament.region.blank?
        parse_and_update_tournament(tournament)
        updated_count += 1
      end
    end
    
    updated_count
  end

  # Método para identificar torneos online por nombre y venue_address
  def identify_online_tournaments_by_name_and_venue
    updated_count = 0
    
    Tournament.find_each do |tournament|
      # Verificar por venue_address
      if tournament.venue_address.present? && online_tournament?(tournament.venue_address)
        unless tournament.region == "Online"
          tournament.update_columns(city: nil, region: "Online")
          updated_count += 1
        end
      # Verificar por nombre del torneo si no hay venue_address clara
      elsif tournament.name.present? && online_tournament_by_name?(tournament.name)
        unless tournament.region == "Online"
          tournament.update_columns(city: nil, region: "Online")
          updated_count += 1
        end
      end
    end
    
    updated_count
  end

  def build_online_keywords
    # Palabras clave que indican torneos online
    {
      venue_keywords: [
        'online', 'wifi', 'discord', 'internet', 'virtual', 'remoto',
        'en línea', 'en linea', 'desde casa', 'digital', 'netplay',
        'quarantine', 'cuarentena', 'lockdown', 'stay home', 'quedateencasa',
        'home', 'casa', 'anywhere', 'cualquier lugar', 'worldwide', 'global',
        'chile'  # Agregar 'chile' como indicador de torneo online
      ],
      name_keywords: [
        'online', 'wifi', 'quarantine', 'lockdown', 'stay home', 'digital',
        'virtual', 'netplay', 'internet', 'discord', 'remoto', 'en casa'
      ]
    }
  end

  def online_tournament?(venue_address)
    return false if venue_address.blank?
    
    normalized_venue = normalize_text(venue_address)
    
    # Verificar si el venue_address contiene palabras clave de torneos online
    @online_keywords[:venue_keywords].any? do |keyword|
      normalized_venue.include?(keyword)
    end
  end

  def online_tournament_by_name?(tournament_name)
    return false if tournament_name.blank?
    
    normalized_name = normalize_text(tournament_name)
    
    # Verificar si el nombre del torneo contiene palabras clave de torneos online
    @online_keywords[:name_keywords].any? do |keyword|
      normalized_name.include?(keyword)
    end
  end

  def load_regions_data
    file_path = Rails.root.join('lib', 'assets', 'comunas_regiones_chile.json')
    JSON.parse(File.read(file_path))
  rescue => e
    Rails.logger.error "Error cargando datos de regiones: #{e.message}"
    { 'regiones' => [] }
  end

  def build_commune_to_region_map
    map = {}
    
    @regions_data['regiones'].each do |region|
      region_name = region['name']
      region['communes'].each do |commune|
        commune_name = normalize_text(commune['name'])
        map[commune_name] = region_name
      end
    end
    
    map
  end

  def normalize_text(text)
    return '' if text.blank?
    
    # Convertir a minúsculas y remover acentos
    text = text.downcase
                .tr('áéíóúñ', 'aeioun')
                .gsub(/[^\w\s]/, ' ')
                .squish
    
    text
  end

  def extract_city(normalized_address)
    # Buscar nombres de comunas en el texto
    words = normalized_address.split(/\s+/)
    
    # Buscar coincidencias exactas primero
    @commune_to_region_map.keys.each do |commune|
      if normalized_address.include?(commune)
        return restore_original_case(commune)
      end
    end
    
    # Buscar por palabras individuales
    words.each do |word|
      next if word.length < 3 # Ignorar palabras muy cortas
      
      @commune_to_region_map.keys.each do |commune|
        if commune.include?(word) || word.include?(commune)
          return restore_original_case(commune)
        end
      end
    end
    
    # Si no encuentra comuna, intentar extraer palabras que parezcan nombres de lugares
    potential_cities = words.select { |word| word.length > 3 && word.match?(/^[a-z]+$/) }
    potential_cities.first&.capitalize
  end

  def extract_region(normalized_address, city)
    # Si encontramos la ciudad, usar el mapeo
    if city && @commune_to_region_map[normalize_text(city)]
      return @commune_to_region_map[normalize_text(city)]
    end
    
    # Buscar nombres de regiones directamente en el texto
    @regions_data['regiones'].each do |region|
      region_name = region['name']
      region_normalized = normalize_text(region_name)
      
      # Buscar nombre completo de la región
      if normalized_address.include?(region_normalized)
        return region_name
      end
      
      # Buscar por abreviación
      if region['abbreviation'] && normalized_address.include?(region['abbreviation'].downcase)
        return region_name
      end
      
      # Buscar palabras clave de la región
      key_words = extract_key_words(region_name)
      key_words.each do |key_word|
        if normalized_address.include?(normalize_text(key_word))
          return region_name
        end
      end
    end
    
    nil
  end

  def extract_key_words(region_name)
    # Extraer palabras significativas del nombre de la región
    words = region_name.split(/\s+/)
    # Filtrar palabras comunes
    stop_words = %w[de del la las el los region y]
    words.reject { |word| stop_words.include?(word.downcase) }
  end

  def restore_original_case(normalized_name)
    # Buscar el nombre original en los datos para mantener la capitalización correcta
    @regions_data['regiones'].each do |region|
      region['communes'].each do |commune|
        if normalize_text(commune['name']) == normalized_name
          return commune['name']
        end
      end
    end
    
    # Si no encuentra, capitalizar cada palabra
    normalized_name.split(' ').map(&:capitalize).join(' ')
  end
end 