FactoryBot.define do
  factory :player do
    entrant_name { Faker::Esport.player }
    name { Faker::Name.name }
    sequence(:user_id) { |n| n }
    discriminator { Faker::Alphanumeric.alphanumeric(number: 4) }

    trait :with_chilean_tag do
      entrant_name { "CL|#{Faker::Esport.player}" }
    end

    trait :with_region_tag do
      entrant_name { "#{[ 'SCL', 'VLP', 'ANF', 'TMC', 'IQQ' ].sample}|#{Faker::Esport.player}" }
    end

    trait :with_team_tag do
      entrant_name { "#{[ 'KOF', 'GG', 'FGC', 'Smash' ].sample} #{Faker::Esport.player}" }
    end

    trait :with_characters do
      character_1 { Player::SMASH_CHARACTERS.keys.sample }
      skin_1 { rand(1..8) }
      character_2 { Player::SMASH_CHARACTERS.keys.sample }
      skin_2 { rand(1..8) }
    end
  end
end
