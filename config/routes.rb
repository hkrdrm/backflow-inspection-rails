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

  # Module routes are always drawn; Backflow::BaseController's module guard is
  # the only gate, so the router never varies per tenant.
  namespace :backflow do
    root to: "home#show"
    resources :testers, only: [ :index, :new, :create, :edit, :update ]
  end

  # The template module (see docs/modules.md). Same shape as every module: one
  # namespace named after the registry key, gated by Example::BaseController.
  namespace :example do
    root to: "home#show"
    resources :items, only: [ :index, :new, :create ]
  end

  namespace :super_admin, path: "super-admin" do
    resources :tenants, only: [ :index, :new, :create, :edit, :update ] do
      member do
        patch :activate
        patch :deactivate
      end

      # POST /super-admin/tenants/:tenant_id/modules (key in the form) adds one;
      # /super-admin/tenants/:tenant_id/modules/:key/enable|disable switch one.
      resources :modules, only: [ :create ], param: :key, controller: "tenant_modules" do
        member do
          patch :enable
          patch :disable
        end
      end
    end
    resources :accounts, only: [ :index, :new, :create, :edit, :update ] do
      member do
        patch :close
        patch :reopen
        patch :grant_super_admin
        patch :revoke_super_admin
        post :impersonate
      end
    end

    # Catalog of modules (created in code, not here) and their platform-wide
    # status (PATCH with status=active|disabled|planned).
    resources :modules, only: [ :index, :update ], param: :key

    root to: "tenants#index"
  end

  # Deliberately outside the super_admin namespace: mid-impersonation
  # current_account is the target, so a namespaced route would 404 the operator
  # into being stuck as that user.
  resource :impersonation, only: [ :destroy ]

  get "about"   => "home#about",   as: :about
  get "contact" => "home#contact", as: :contact
end
