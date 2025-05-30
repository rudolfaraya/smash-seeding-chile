Rails.application.routes.draw do
  get "email_viewer", to: "email_viewer#index"
  get "email_viewer/:id", to: "email_viewer#show", as: :email_viewer_show
  get "email_test/send_test"
  post "email_test/send_test"
  devise_for :users
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :tournaments do
    collection do
      post :sync # Ruta para sincronizar torneos y eventos
      post :sync_new_tournaments # Nueva ruta para sincronizar solo nuevos torneos
      post :sync_latest_tournaments # Nueva ruta para actualizar últimos torneos
    end

    member do
      post :sync_events # Ruta para sincronizar eventos de un torneo específico
    end

    resources :events, only: [ :index, :show ] do
      member do
        get :seeds, to: "events#seeds", as: :seeds # Añadimos nombre explícito para la ruta de seeds
        get :sync_seeds, to: "events#sync_seeds" # Permitir GET para sync_seeds
        post :sync_seeds, to: "events#sync_seeds" # Ruta para sincronizar seeds y players
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  root "tournaments#index"

  # Players routes
  resources :players, only: [ :index ] do
    collection do
      get :search
    end
    member do
      patch :update_smash_characters
      get :current_characters
      get :edit_info
      patch :update_info
      get :edit_teams
      patch :update_teams
    end
  end

  # Teams routes
  resources :teams, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    collection do
      get :search
    end
    member do
      post :add_player
      delete :remove_player
      get :search_players
    end
  end

  # Mission Control Jobs - Panel de administración de jobs
  # Solo accesible para usuarios autenticados
  authenticate :user do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Estadísticas
  get "stats" => "stats#index", as: :stats

  # Solicitudes de vinculación de jugadores
  resources :user_player_requests, except: [:edit, :update, :destroy] do
    collection do
      get :search_players
      get :debug # Ruta temporal para debug
    end
    member do
      delete :cancel
    end
  end

  # Perfil de usuario
  get '/profile', to: 'profile#show', as: :profile
  get '/profile/edit', to: 'profile#edit', as: :edit_profile
  patch '/profile', to: 'profile#update'
  get '/profile/player', to: 'profile#player', as: :profile_player
  get '/profile/player/edit', to: 'profile#edit_player', as: :edit_profile_player
  patch '/profile/player', to: 'profile#update_player'

  # Rutas de administración
  namespace :admin do
    resources :user_player_requests, only: [:index, :show] do
      member do
        patch :approve
        patch :reject
      end
      collection do
        get :bulk_review
        get :stats
      end
    end
  end
end
