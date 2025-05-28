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
end 