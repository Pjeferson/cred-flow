# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate!

      private

      def authenticate!
        token = request.headers["Authorization"]&.sub(/\ABearer\s+/, "")
        return render_unauthorized unless token

        payload = JWT.decode(
          token,
          ENV.fetch("DEVISE_JWT_SECRET_KEY"),
          true,
          algorithms: ["HS256"]
        ).first
        @current_user_id = payload["sub"]
      rescue JWT::DecodeError
        render_unauthorized
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def render_errors(failure)
        case failure
        when Hash
          status = failure.delete(:status) { :unprocessable_entity }
          render json: failure, status: status
        else
          render json: { error: failure.to_s }, status: :unprocessable_entity
        end
      end
    end
  end
end
