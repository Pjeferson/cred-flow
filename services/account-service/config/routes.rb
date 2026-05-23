# frozen_string_literal: true

Rails.application.routes.draw do
  # devise_for fora de qualquer namespace — requisito do devise-jwt
  devise_for :users,
    path: "api/v1/auth",
    path_names: {
      sign_in: "sign_in",
      sign_out: "sign_out",
      registration: "sign_up"
    },
    controllers: {
      sessions:      "api/v1/auth/sessions",
      registrations: "api/v1/auth/registrations"
    }

  namespace :api do
    namespace :v1 do
      resources :participants, only: %i[index show create] do
        post :kyc_check, on: :member
      end

      resources :accounts, only: %i[index show create] do
        get  :balance,        on: :member
        resources :ledger_entries, only: :index
      end
    end
  end

  namespace :internal do
    resources :accounts, only: :show
    resources :accounts, only: [] do
      resources :ledger_entries, only: %i[index create]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
