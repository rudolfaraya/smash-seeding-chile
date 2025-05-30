class AddPlacementsLastSyncedAtToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :placements_last_synced_at, :datetime
  end
end
