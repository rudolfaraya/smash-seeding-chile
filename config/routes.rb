Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :tournaments do
    collection do
      post :sync # Ruta para sincronizar torneos y eventos
      post :sync_new_tournaments # Nueva ruta para sincronizar solo nuevos torneos
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
    end
  end

  # Mission Control Jobs - Panel de administración de jobs
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
