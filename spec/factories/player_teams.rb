FactoryBot.define do
  factory :player_team do
    player { nil }
    team { nil }
    is_primary { false }
  end
end
