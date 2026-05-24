# frozen_string_literal: true

module AuthHelpers
  # payment-service BaseController só decodifica o JWT — não busca User no DB
  def auth_headers(user_id = SecureRandom.uuid)
    payload = { sub: user_id.to_s, exp: 24.hours.from_now.to_i }
    token   = JWT.encode(payload, ENV.fetch("DEVISE_JWT_SECRET_KEY"), "HS256")
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
