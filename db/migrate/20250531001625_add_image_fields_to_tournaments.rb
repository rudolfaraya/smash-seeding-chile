class AddImageFieldsToTournaments < ActiveRecord::Migration[7.2]
  def change
    add_column :tournaments, :banner_image_url, :string
    add_column :tournaments, :banner_image_width, :integer
    add_column :tournaments, :banner_image_height, :integer
    add_column :tournaments, :banner_image_ratio, :float
  end
end
