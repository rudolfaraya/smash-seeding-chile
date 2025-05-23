module ApplicationHelper
  # Formatear fecha y hora para mostrar en Chile
  def format_datetime_cl(datetime)
    return 'No disponible' unless datetime
    
    datetime.in_time_zone('America/Santiago').strftime('%d/%m/%Y %H:%M')
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
end
