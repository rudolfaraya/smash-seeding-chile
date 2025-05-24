class AddStartGgEventIdToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :start_gg_event_id, :integer
  end
end
