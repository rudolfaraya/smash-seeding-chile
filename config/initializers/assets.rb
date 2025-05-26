# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )

# Configuración para optimizar assets y evitar warnings de preload
if Rails.env.development?
  # En desarrollo, reducir el uso agresivo de preload
  Rails.application.config.assets.preload = []

  # Configurar cache de assets para desarrollo
  Rails.application.config.assets.cache_store = :null_store
end
