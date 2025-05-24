module TournamentsHelper
  def filter_options_for(options, label_singular)
    [["Todas las #{label_singular}s", '']] + options.map { |opt| [opt, opt] }
  end

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
    params[:region].present? || params[:city].present?
  end

  def clear_filters_path
    tournaments_path(query: params[:query])
  end

  def remove_region_filter_path
    tournaments_path(query: params[:query], city: params[:city])
  end

  def remove_city_filter_path
    tournaments_path(query: params[:query], region: params[:region])
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