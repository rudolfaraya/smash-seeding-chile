FactoryBot.define do
  factory :tournament do
    sequence(:name) { |n| "Tournament #{n}" }
    sequence(:slug) { |n| "tournament-#{n}" }
    start_at { 1.week.from_now }
    venue_address { "Centro de Eventos, Santiago, Región Metropolitana" }
    city { "Santiago" }
    region { "Metropolitana de Santiago" }
    
    # Asegurar que se genere la URL de start.gg
    after(:build) do |tournament|
      tournament.start_gg_url = "https://www.start.gg/#{tournament.slug}" if tournament.slug.present?
    end

    trait :online do
      name { "Discord Weekly" }
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
      name { "Santiago Major" }
      venue_address { "Centro de Eventos Los Leones, Santiago, Región Metropolitana" }
      city { "Santiago" }
      region { "Metropolitana de Santiago" }
    end

    trait :valparaiso do
      name { "Valparaíso Cup" }
      venue_address { "Centro Cultural Valparaíso, Valparaíso, Región de Valparaíso" }
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
      name { "Past Event" }
      start_at { 1.week.ago }
    end

    trait :future do
      start_at { Faker::Time.forward(days: 60, period: :morning) }
    end
  end
end
