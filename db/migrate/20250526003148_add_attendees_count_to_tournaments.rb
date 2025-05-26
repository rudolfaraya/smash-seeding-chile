class AddAttendeesCountToTournaments < ActiveRecord::Migration[7.2]
  def change
    add_column :tournaments, :attendees_count, :integer
  end
end
