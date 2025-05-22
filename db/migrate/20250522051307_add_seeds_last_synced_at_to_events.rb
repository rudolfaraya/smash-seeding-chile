class AddSeedsLastSyncedAtToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :seeds_last_synced_at, :datetime
  end
end
