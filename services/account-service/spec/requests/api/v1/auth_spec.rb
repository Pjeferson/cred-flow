# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth", type: :request do
  let(:user) { create(:user, password: "secret123") }

  describe "POST /api/v1/auth/sign_in" do
    it "returns JWT on valid credentials" do
      post "/api/v1/auth/sign_in",
           params:  { user: { email: user.email, password: "secret123" } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.headers["Authorization"]).to match(/\ABearer .+\z/)
    end

    it "returns 401 on wrong password" do
      post "/api/v1/auth/sign_in",
           params:  { user: { email: user.email, password: "wrong" } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for unknown email" do
      post "/api/v1/auth/sign_in",
           params:  { user: { email: "no@one.com", password: "secret123" } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    it "returns 200 using the token obtained from sign_in" do
      post "/api/v1/auth/sign_in",
           params:  { user: { email: user.email, password: "secret123" } }.to_json,
           headers: json_headers

      token = response.headers["Authorization"]
      delete "/api/v1/auth/sign_out", headers: { "Authorization" => token }
      expect(response).to have_http_status(:ok)
    end
  end
end
