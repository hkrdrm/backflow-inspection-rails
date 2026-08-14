Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  get "dashboard" => "dashboard#show", as: :dashboard

  resources :plumbers, only: [ :index, :new, :create, :edit, :update ]

  namespace :super_admin, path: "super-admin" do
    resources :tenants, only: [ :index, :new, :create, :edit, :update ] do
      member do
        patch :activate
        patch :deactivate
      end
    end
    resources :accounts, only: [ :index ]

    root to: "tenants#index"
  end

  get "about"   => "home#about",   as: :about
  get "contact" => "home#contact", as: :contact
end
