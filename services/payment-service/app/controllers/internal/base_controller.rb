# frozen_string_literal: true

module Internal
  class BaseController < ApplicationController
    before_action :verify_service_key

    private

    def verify_service_key
      provided = request.headers["X-Service-Key"]
      expected = ENV.fetch("INTERNAL_SERVICE_KEY", "credflow-internal")
      render json: { error: "Forbidden" }, status: :forbidden unless provided == expected
    end
  end
end
