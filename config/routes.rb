Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :tournaments do
    resources :events, only: [:index, :show] do
      member do
        get :seeds, to: "events#seeds" # Ruta para mostrar seeds
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
end
