module ApplicationHelper
  # Formatear fecha y hora para mostrar en Chile
  def format_datetime_cl(datetime)
    return "Sin fecha" if datetime.blank?

    # Convertir a zona horaria de Chile
    chile_time = datetime.in_time_zone("America/Santiago")

    # Formatear en español
    chile_time.strftime("%d/%m/%Y %H:%M")
  end

  # Formatear solo fecha para mostrar en Chile
  def format_date_cl(date)
    return "No disponible" unless date

    date.in_time_zone("America/Santiago").strftime("%d/%m/%Y")
  end

  # Formatear fecha y hora para input datetime-local (formato ISO)
  def format_datetime_input_cl(datetime)
    return "" unless datetime

    datetime.in_time_zone("America/Santiago").strftime("%Y-%m-%dT%H:%M")
  end

  # Formatear fecha para mostrar torneo (formato más legible)
  def format_tournament_date_cl(datetime)
    return "Fecha no disponible" unless datetime

    datetime.in_time_zone("America/Santiago").strftime("%d de %B de %Y, %H:%M")
  end

  # Helper para cargar CSS de manera eficiente sin preload warnings
  def efficient_stylesheet_link_tag(*sources)
    options = sources.extract_options!

    # En desarrollo, usar carga normal sin preload
    if Rails.env.development?
      options.merge!("data-turbo-track": "reload", preload: false)
    else
      # En producción, usar la estrategia normal
      options.merge!("data-turbo-track": "reload")
    end

    stylesheet_link_tag(*sources, options)
  end

  # Helper para mostrar íconos de personajes de Smash
  def smash_character_icon(character, skin = 1, options = {})
    return "" if character.blank?

    # Verificar si es un personaje sin skins
    is_character_without_skins = Player::CHARACTERS_WITHOUT_SKINS.include?(character)

    # Configurar opciones por defecto con borde más sutil
    skin_text = is_character_without_skins ? "Personalizable" : "Skin #{skin}"
    default_options = {
      class: "smash-character-icon",
      alt: Player::SMASH_CHARACTERS[character] || character.humanize,
      title: "#{Player::SMASH_CHARACTERS[character] || character.humanize} (#{skin_text})",
      width: 32,
      height: 32
    }

    options = default_options.merge(options)

    # Construir la ruta del asset
    if is_character_without_skins
      asset_path = "smash/characters/#{character}.png"
    else
      asset_path = "smash/characters/#{character}_#{skin}.png"
    end

    # Verificar si el asset existe, si no usar un placeholder
    if Rails.application.assets&.find_asset(asset_path) || File.exist?(Rails.root.join("app", "assets", "images", asset_path))
      image_tag(asset_path, options.merge(
        class: "#{options[:class]} border border-slate-700 rounded-md bg-slate-800 shadow-sm",
        style: "filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));"
      ))
    else
      # Placeholder si no existe el asset
      content_tag(:div,
        content_tag(:span, character[0].upcase, class: "text-xs font-bold"),
        class: "#{options[:class]} bg-slate-600 text-slate-200 rounded-full flex items-center justify-center border border-slate-700",
        style: "width: #{options[:width]}px; height: #{options[:height]}px; filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));",
        title: options[:title]
      )
    end
  end

  # Helper para generar opciones de select para personajes
  def smash_character_options
    Player::SMASH_CHARACTERS.map { |key, name| [ name, key ] }.sort_by(&:first)
  end

  # Helper para generar opciones de select para skins (1-8)
  def smash_skin_options
    (1..8).map { |i| [ "Skin #{i}", i ] }
  end

  def prepare_players_data(players)
    players.map do |player|
      {
        id: player.id,
        gamer_tag: player.gamer_tag,
        name: player.name,
        smash_character_1: player.smash_character_1,
        smash_character_2: player.smash_character_2,
        smash_character_3: player.smash_character_3,
        smash_skin_1: player.smash_skin_1,
        smash_skin_2: player.smash_skin_2,
        smash_skin_3: player.smash_skin_3
      }
    end
  end

  def prepare_location_filters
    {
      regions: Tournament.where.not(region: [ nil, "" ]).distinct.pluck(:region).sort,
      cities: Tournament.where.not(city: [ nil, "" ]).distinct.pluck(:city).sort
    }
  end

  # Helper específico para mostrar el personaje principal en la vista de players
  # Optimizado para mostrar como avatar cuadrado recortado cerca de los ojos
  def player_main_character_avatar(player, options = {})
    return "" if player.character_1.blank?

    # Configurar opciones por defecto para avatar
    default_options = {
      class: "player-character-avatar",
      alt: Player::SMASH_CHARACTERS[player.character_1] || player.character_1.humanize,
      title: "#{Player::SMASH_CHARACTERS[player.character_1] || player.character_1.humanize} (Skin #{player.skin_1 || 1})",
      width: 48,
      height: 48
    }

    options = default_options.merge(options)

    # Intentar primero con character_individual_skins
    skin_number = player.skin_1 || 1
    skin_file_number = skin_number - 1
    individual_asset_path = "smash/character_individual_skins/#{player.character_1}/#{player.character_1}_skin_#{skin_file_number}.png"
    
    # Fallback a characters con skin
    characters_asset_path = "smash/characters/#{player.character_1}_#{skin_number}.png"
    
    # Determinar qué asset usar
    asset_path = nil
    if Rails.application.assets&.find_asset(individual_asset_path) || File.exist?(Rails.root.join("app", "assets", "images", individual_asset_path))
      asset_path = individual_asset_path
    elsif Rails.application.assets&.find_asset(characters_asset_path) || File.exist?(Rails.root.join("app", "assets", "images", characters_asset_path))
      asset_path = characters_asset_path
    end

    if asset_path
      # Estilos diferentes para avatar grande vs pequeño
      if options[:class]&.include?("large-character-avatar")
        image_tag(asset_path, options.merge(
          class: "#{options[:class]}",
          style: "position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) scale(3.5); width: #{options[:width]}px; height: #{options[:height]}px; object-fit: cover; object-position: center 5%; filter: contrast(1.1) saturate(1.1) brightness(1.05);"
        ))
      else
        image_tag(asset_path, options.merge(
          class: "#{options[:class]} rounded-lg border-2 border-slate-600 bg-slate-800 shadow-lg object-cover object-top",
          style: "filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.4)); object-position: center 20%;"
        ))
      end
    else
      # Placeholder si no existe el asset
      content_tag(:div,
        content_tag(:span, player.character_1[0].upcase, class: "text-lg font-bold"),
        class: "#{options[:class]} bg-gradient-to-br from-slate-600 to-slate-700 text-slate-200 rounded-lg flex items-center justify-center border-2 border-slate-600 shadow-lg",
        style: "width: #{options[:width]}px; height: #{options[:height]}px; filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.4));",
        title: options[:title]
      )
    end
  end
end
