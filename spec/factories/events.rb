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
    end
    
    trait :amateur do
      name { "Super Smash Bros. Ultimate Amateur" }
      slug { "ultimate-amateur" }
    end
    
    trait :with_seeds do
      after(:create) do |event|
        create_list(:event_seed, 8, event: event)
      end
    end
    
    trait :large do
      name { "Large Tournament Event" }
    end
    
    trait :small do
      name { "Small Tournament Event" }
    end
  end
end 