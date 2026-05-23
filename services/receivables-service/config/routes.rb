# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :ccbs, only: %i[index show create]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
