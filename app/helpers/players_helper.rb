module PlayersHelper
  def country_options
    # Obtener países ordenados por cantidad de jugadores
    countries_with_count = Player.where.not(country: [nil, ''])
                                 .group(:country)
                                 .count
                                 .sort_by { |country, count| -count }
    
    # Convertir a opciones para select
    countries_with_count.map do |country, count|
      ["#{country} (#{count})", country]
    end
  end

  def smash_character_options
    Player::SMASH_CHARACTERS.map do |key, name|
      [name, key]
    end.sort_by { |name, key| name }
  end

  def team_options
    Team.order(:name).map do |team|
      ["#{team.display_name} (#{team.players_count})", team.id]
    end
  end

  def commune_options_for_chile
    # Cargar el archivo JSON con las comunas de Chile
    file_path = Rails.root.join('lib', 'assets', 'comunas_regiones_chile.json')
    
    begin
      data = JSON.parse(File.read(file_path))
      communes = []
      
      # Extraer todas las comunas de todas las regiones
      data['regiones'].each do |region|
        region['communes'].each do |commune|
          communes << commune['name']
        end
      end
      
      # Ordenar alfabéticamente y convertir a formato para select
      communes.sort.map { |commune| [commune, commune] }
    rescue => e
      Rails.logger.error "Error cargando comunas de Chile: #{e.message}"
      # Fallback en caso de error
      []
    end
  end
end 