FactoryBot.define do
  factory :event_seed do
    association :event
    association :player
    sequence(:seed_num) { |n| n }
    
    trait :top_seed do
      seed_num { 1 }
    end
    
    trait :low_seed do
      seed_num { Faker::Number.between(from: 16, to: 64) }
    end
    
    trait :mid_seed do
      seed_num { Faker::Number.between(from: 4, to: 16) }
    end
    
    trait :unseeded do
      seed_num { nil }
    end
  end
end 