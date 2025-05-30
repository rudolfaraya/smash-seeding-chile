# frozen_string_literal: true

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

    # Usar la estructura correcta para iconos pequeños: smash/characters/nombre_personaje_numero_skin.png
    skin_number = is_character_without_skins ? 1 : (skin || 1)
    asset_path = "smash/characters/#{character}_#{skin_number}.png"

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

    # Determinar la ruta del asset según la nueva estructura
    asset_path = nil
    
    # Verificar si es un personaje Mii (sin skins)
    if Player::CHARACTERS_WITHOUT_SKINS.include?(player.character_1)
      # Para Mii: usar solo el nombre del personaje (brawler.png, gunner.png, swordfighter.png)
      mii_name = case player.character_1
                 when "mii_brawler" then "brawler"
                 when "mii_gunner" then "gunner"
                 when "mii_swordfighter" then "swordfighter"
                 else player.character_1
                 end
      asset_path = "smash/character_individual_skins/#{player.character_1}/#{mii_name}.png"
    else
      # Para personajes normales: usar skin del 1 al 8
      skin_number = player.skin_1 || 1
      asset_path = "smash/character_individual_skins/#{player.character_1}/#{skin_number}.png"
    end

    # Verificar si el asset existe
    if Rails.application.assets&.find_asset(asset_path) || File.exist?(Rails.root.join("app", "assets", "images", asset_path))
      # Estilos optimizados para imágenes de 430x150px
      if options[:class]&.include?("large-character-avatar")
        # Para la columna de personaje: ocupar toda la celda disponible
        # Respetar estilos forzados si se pasan como parámetro
        final_options = options.dup
        if options[:style].present?
          final_options[:style] = options[:style]
        end
        image_tag(asset_path, final_options)
      else
        image_tag(asset_path, options.merge(
          class: "#{options[:class]}",
          style: "width: #{options[:width]}px; height: #{options[:height]}px; object-fit: cover;"
        ))
      end
    else
      # Placeholder si no existe el asset
      content_tag(:div,
        content_tag(:span, player.character_1[0].upcase, class: "text-lg font-bold"),
        class: "#{options[:class]} bg-gradient-to-br from-slate-600 to-slate-700 text-slate-200 rounded-lg flex items-center justify-center border-2 border-slate-600 shadow-lg",
        style: "width: #{options[:width]}px; height: #{options[:height]}px;",
        title: options[:title]
      )
    end
  end

  # Helper para mostrar caracteres especiales en la información del jugador
  def format_player_info(text)
    return '' if text.blank?
    simple_format(text, {}, wrapper_tag: "div")
  end

  # Opciones para el filtro por equipos
  def team_options
    Team.order(:name).map { |team| [team.display_name, team.id] }
  end

  # Opciones para regiones basadas en torneos existentes
  def region_options
    Tournament.where.not(region: [nil, ""])
             .distinct
             .pluck(:region)
             .sort
             .map { |region| [region, region] }
  end

  # Opciones para equipos con información visual (para multi-select)
  def teams_with_details
    Team.order(:name).map do |team|
      {
        id: team.id,
        name: team.name,
        acronym: team.acronym,
        logo: team.logo,
        display_name: team.display_name
      }
    end
  end

  # Helper para verificar si el usuario puede acceder a Mission Control Jobs
  def can_access_jobs?
    user_signed_in? && current_user.admin?
  end

  # Helper para obtener la ruta de Mission Control Jobs de forma segura
  def safe_mission_control_jobs_path
    return new_user_session_path unless can_access_jobs?
    
    "/jobs"
  end

  # Helpers para Pundit
  def can_edit_player?(player)
    user_signed_in? && policy(player).update?
  end
  
  def can_sync_tournaments?
    user_signed_in? && policy(Tournament).sync?
  end
  
  def can_sync_events?(event)
    user_signed_in? && policy(event).sync_seeds?
  end
  
  def can_manage_teams?
    user_signed_in? && current_user.admin?
  end
  
  def show_admin_controls?
    user_signed_in? && current_user.admin?
  end
  
  def show_player_edit_controls?(player)
    user_signed_in? && (current_user.admin? || current_user.player == player)
  end
end
