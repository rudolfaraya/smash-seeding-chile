class AddDefaultStatusToUserPlayerRequests < ActiveRecord::Migration[7.2]
  def change
    change_column_default :user_player_requests, :status, 0
  end
end
