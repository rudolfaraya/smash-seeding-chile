class AddStartGgUrlToTournaments < ActiveRecord::Migration[7.2]
  def change
    add_column :tournaments, :start_gg_url, :string
  end
end
