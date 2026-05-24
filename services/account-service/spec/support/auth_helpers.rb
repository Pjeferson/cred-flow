# frozen_string_literal: true

module AuthHelpers
  def auth_headers(user)
    payload = {
      sub: user.id.to_s,
      scp: "user",
      jti: SecureRandom.uuid,
      exp: 24.hours.from_now.to_i
    }
    token = JWT.encode(payload, ENV.fetch("DEVISE_JWT_SECRET_KEY"), "HS256")
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
