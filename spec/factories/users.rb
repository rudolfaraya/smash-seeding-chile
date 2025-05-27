FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "usuario#{n}@ejemplo.com" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }
    confirmation_sent_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
      confirmation_sent_at { Time.current }
      confirmation_token { SecureRandom.hex(10) }
    end

    # Trait comentado porque :lockable no está habilitado
    # trait :locked do
    #   locked_at { Time.current }
    #   failed_attempts { 5 }
    #   unlock_token { SecureRandom.hex(10) }
    # end

    trait :with_reset_password do
      reset_password_token { SecureRandom.hex(10) }
      reset_password_sent_at { Time.current }
    end

    trait :with_remember_me do
      remember_created_at { Time.current }
    end
  end
end
