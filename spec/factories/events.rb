FactoryBot.define do
  factory :event do
    association :tournament
    name { "Super Smash Bros. Ultimate Singles" }
    slug { "ultimate-singles" }
    
    trait :singles do
      name { "Super Smash Bros. Ultimate Singles" }
      slug { "ultimate-singles" }
    end
    
    trait :doubles do
      name { "Super Smash Bros. Ultimate Doubles" }
      slug { "ultimate-doubles" }
      num_entrants { Faker::Number.between(from: 4, to: 32) }
    end
    
    trait :amateur do
      name { "Super Smash Bros. Ultimate Amateur" }
      slug { "ultimate-amateur" }
      num_entrants { Faker::Number.between(from: 8, to: 64) }
    end
    
    trait :with_seeds do
      after(:create) do |event|
        create_list(:event_seed, [event.num_entrants, 32].min, event: event)
      end
    end
    
    trait :large do
      num_entrants { Faker::Number.between(from: 64, to: 256) }
    end
    
    trait :small do
      num_entrants { Faker::Number.between(from: 8, to: 16) }
    end
  end
end 