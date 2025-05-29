class AddAttendeesCountToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :attendees_count, :integer
  end
end
