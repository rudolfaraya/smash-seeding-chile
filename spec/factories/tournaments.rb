FactoryBot.define do
  factory :tournament do
    sequence(:name) { |n| "#{Faker::Esport.event} #{n}" }
    sequence(:slug) { |n| "tournament-#{n}" }
    start_at { Faker::Time.forward(days: 30, period: :morning) }
    venue_address { "#{Faker::Address.street_address}, Santiago, Región Metropolitana" }

    city { "Santiago" }
    region { "Metropolitana de Santiago" }

    trait :online do
      venue_address { "Chile" }
      city { nil }
      region { "Online" }
    end

    trait :with_online_keywords do
      venue_address { [ "Online", "Discord", "WiFi", "Internet" ].sample }
      city { nil }
      region { "Online" }
    end

    trait :santiago do
      venue_address { "#{Faker::Address.street_address}, Santiago, Región Metropolitana" }
      city { "Santiago" }
      region { "Metropolitana de Santiago" }
    end

    trait :valparaiso do
      venue_address { "#{Faker::Address.street_address}, Valparaíso, Valparaíso" }
      city { "Valparaíso" }
      region { "Valparaíso" }
    end

    trait :antofagasta do
      venue_address { "#{Faker::Address.street_address}, Antofagasta, Antofagasta" }
      city { "Antofagasta" }
      region { "Antofagasta" }
    end

    trait :with_events do
      after(:create) do |tournament|
        create_list(:event, 2, tournament: tournament)
      end
    end

    trait :past do
      start_at { Faker::Time.backward(days: 30, period: :morning) }
    end

    trait :future do
      start_at { Faker::Time.forward(days: 60, period: :morning) }
    end
  end
end
