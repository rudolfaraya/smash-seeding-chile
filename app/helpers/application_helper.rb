module ApplicationHelper
  # Formatear fecha y hora para mostrar en Chile
  def format_datetime_cl(datetime)
    return 'Sin fecha' if datetime.blank?
    
    # Convertir a zona horaria de Chile
    chile_time = datetime.in_time_zone('America/Santiago')
    
    # Formatear en español
    chile_time.strftime('%d/%m/%Y %H:%M')
  end
  
  # Formatear solo fecha para mostrar en Chile
  def format_date_cl(date)
    return 'No disponible' unless date
    
    date.in_time_zone('America/Santiago').strftime('%d/%m/%Y')
  end
  
  # Formatear fecha y hora para input datetime-local (formato ISO)
  def format_datetime_input_cl(datetime)
    return '' unless datetime
    
    datetime.in_time_zone('America/Santiago').strftime('%Y-%m-%dT%H:%M')
  end
  
  # Formatear fecha para mostrar torneo (formato más legible)
  def format_tournament_date_cl(datetime)
    return 'Fecha no disponible' unless datetime
    
    datetime.in_time_zone('America/Santiago').strftime('%d de %B de %Y, %H:%M')
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
    return '' if character.blank?
    
    # Configurar opciones por defecto con borde más sutil
    default_options = {
      class: 'smash-character-icon',
      alt: Player::SMASH_CHARACTERS[character] || character.humanize,
      title: "#{Player::SMASH_CHARACTERS[character] || character.humanize} (Skin #{skin})",
      width: 32,
      height: 32
    }
    
    options = default_options.merge(options)
    
    # Construir la ruta del asset
    asset_path = "smash/characters/#{character}_#{skin}.png"
    
    # Verificar si el asset existe, si no usar un placeholder
    if Rails.application.assets&.find_asset(asset_path) || File.exist?(Rails.root.join('app', 'assets', 'images', asset_path))
      image_tag(asset_path, options.merge(
        class: "#{options[:class]} border border-slate-700 rounded-md bg-slate-800 shadow-sm",
        style: "filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));"
      ))
    else
      # Placeholder si no existe el asset
      content_tag(:div, 
        content_tag(:span, character[0].upcase, class: 'text-xs font-bold'),
        class: "#{options[:class]} bg-slate-600 text-slate-200 rounded-full flex items-center justify-center border border-slate-700",
        style: "width: #{options[:width]}px; height: #{options[:height]}px; filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));",
        title: options[:title]
      )
    end
  end

  # Helper para generar opciones de select para personajes
  def smash_character_options
    Player::SMASH_CHARACTERS.map { |key, name| [name, key] }.sort_by(&:first)
  end

  # Helper para generar opciones de select para skins (1-8)
  def smash_skin_options
    (1..8).map { |i| ["Skin #{i}", i] }
  end
end
