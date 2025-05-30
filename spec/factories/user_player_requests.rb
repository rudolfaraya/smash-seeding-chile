FactoryBot.define do
  factory :user_player_request do
    user { nil }
    player { nil }
    status { 1 }
    message { "MyText" }
    admin_response { "MyText" }
    requested_at { "2025-05-29 16:05:55" }
    responded_at { "2025-05-29 16:05:55" }
  end
end
