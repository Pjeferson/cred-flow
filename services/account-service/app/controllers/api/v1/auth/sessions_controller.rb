# frozen_string_literal: true

module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          render json: {
            message: "Logged in successfully",
            user: { id: resource.id, email: resource.email, name: resource.name }
          }, status: :ok
        end

        # Gotcha devise-jwt: assinatura com (**) evita 401 em setup stateless
        def respond_to_on_destroy(**)
          render json: { message: "Logged out successfully" }, status: :ok
        end
      end
    end
  end
end
