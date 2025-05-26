source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.2", ">= 7.2.2.1"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 1.4"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec testing framework
  gem "rspec-rails", "~> 6.1"

  # Factory Bot for test data generation
  gem "factory_bot_rails", "~> 6.4"

  # Faker for realistic test data
  gem "faker", "~> 3.4"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara", "~> 3.40"
  gem "selenium-webdriver"

  # Shoulda matchers for cleaner model tests
  gem "shoulda-matchers", "~> 6.0"

  # WebMock for stubbing HTTP requests
  gem "webmock", "~> 3.19"

  # VCR for recording HTTP interactions
  gem "vcr", "~> 6.2"

  # Database cleaner for clean test state
  gem "database_cleaner-active_record", "~> 2.1"

  # Simplecov for code coverage
  gem "simplecov", "~> 0.22", require: false

  # Test profiling
  gem "test-prof", "~> 1.3"
end

gem "httparty", "~> 0.22.0" # Para consultas a la API de Start.gg

gem "nokogiri", "~> 1.18" # Para scraping de SSBWiki

gem "dotenv-rails", "~> 3.1"

gem "faraday", "~> 2.12"

gem "kaminari", "~> 1.2" # Para paginación

gem "solid_queue", "~> 1.1"

gem "mission_control-jobs", "~> 1.0"
