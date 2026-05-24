# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :payment_orders, only: %i[index show create] do
        resources :approvals, only: :create
      end
    end
  end

  namespace :internal do
    post "e2e/seed", to: "e2e#seed"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
