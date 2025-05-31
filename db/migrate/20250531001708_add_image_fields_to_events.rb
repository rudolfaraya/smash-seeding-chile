class AddImageFieldsToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :profile_image_url, :string
    add_column :events, :profile_image_width, :integer
    add_column :events, :profile_image_height, :integer
    add_column :events, :profile_image_ratio, :float
  end
end
