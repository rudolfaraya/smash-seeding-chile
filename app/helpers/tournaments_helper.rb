module TournamentsHelper
  def filter_options_for(options, label_singular)
    plural_label = pluralize_spanish(label_singular.downcase)
    [["Todas las #{plural_label}", '']] + options.map { |opt| [opt, opt] }
  end

  private

  def pluralize_spanish(word)
    case word
    when 'región'
      'regiones'
    when 'ciudad'
      'ciudades'
    when /[aeiou]$/
      "#{word}s"
    when /[^aeiou]$/
      "#{word}es"
    else
      "#{word}s"
    end
  end

  public

  def tournament_search_data_attributes
    {
      controller: "search",
      turbo_frame: "tournaments_results",
      action: "submit->search#preventSubmit input->search#debouncedSubmit"
    }
  end

  def search_input_data_attributes
    {
      search_target: "input",
      action: "keyup->search#debouncedSubmit input->search#debouncedSubmit"
    }
  end

  def filter_select_data_attributes
    {
      action: "change->search#selectChanged"
    }
  end

  def has_active_filters?
    params[:region].present? || params[:city].present? || params[:status].present? || 
    params[:start_date].present? || params[:end_date].present? || 
    (params[:sort].present? && params[:sort] != 'newest')
  end

  def has_any_filters?
    params[:query].present? || has_active_filters?
  end

  def clear_filters_path
    tournaments_path(query: params[:query], sort: params[:sort])
  end

  def clear_all_filters_path
    tournaments_path
  end

  def sort_options_for_select
    [
      ['Más nuevos', 'newest'],
      ['Más antiguos', 'oldest'],
      ['Más asistentes', 'most_attendees'],
      ['Menos asistentes', 'least_attendees'],
      ['Alfabético A-Z', 'alphabetical_az'],
      ['Alfabético Z-A', 'alphabetical_za']
    ]
  end

  def remove_region_filter_path
    tournaments_path(query: params[:query], city: params[:city], sort: params[:sort])
  end

  def remove_city_filter_path
    tournaments_path(query: params[:query], region: params[:region], sort: params[:sort])
  end

  def sync_operation_data_attributes
    {
      controller: "sync-operation",
      sync_operation_target: "button",
      action: "click->sync-operation#startSync",
      turbo_method: :post,
      turbo_frame: "tournaments_results"
    }
  end
end 