class AddCityAndRegionToTournaments < ActiveRecord::Migration[7.2]
  def change
    add_column :tournaments, :city, :string
    add_column :tournaments, :region, :string
    add_index :tournaments, :region
    add_index :tournaments, :city
  end
end
