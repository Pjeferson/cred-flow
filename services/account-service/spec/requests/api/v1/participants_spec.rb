# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Participants", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/participants" do
    it "returns 401 without auth" do
      get "/api/v1/participants"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns an empty list when no participants exist" do
      get "/api/v1/participants", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]).to eq([])
    end

    it "returns all participants" do
      create_list(:participant, 3)
      get "/api/v1/participants", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(3)
    end
  end

  describe "GET /api/v1/participants/:id" do
    let(:participant) { create(:participant) }

    it "returns 401 without auth" do
      get "/api/v1/participants/#{participant.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the participant" do
      get "/api/v1/participants/#{participant.id}", headers: headers
      expect(response).to have_http_status(:ok)
      attrs = json_body["data"]["attributes"]
      expect(attrs["name"]).to eq(participant.name)
      expect(attrs["document"]).to eq(participant.document)
      expect(attrs["role"]).to eq(participant.role)
      expect(attrs["kyc_status"]).to eq(participant.kyc_status)
    end

    it "returns 404 for unknown id" do
      get "/api/v1/participants/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/participants" do
    let(:valid_params) do
      {
        participant: {
          name:     "Empresa Cedente Ltda",
          document: "12.345.678/0001-90",
          role:     "cedente",
          email:    "cedente@empresa.com"
        }
      }
    end

    it "returns 401 without auth" do
      post "/api/v1/participants", params: valid_params.to_json, headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a participant with valid params" do
      post "/api/v1/participants", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      attrs = json_body["data"]["attributes"]
      expect(attrs["name"]).to eq("Empresa Cedente Ltda")
      expect(attrs["kyc_status"]).to eq("pending")
    end

    it "returns 422 when document format is invalid" do
      invalid = valid_params.deep_merge(participant: { document: "not-a-doc" })
      post "/api/v1/participants", params: invalid.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when role is invalid" do
      invalid = valid_params.deep_merge(participant: { role: "alien" })
      post "/api/v1/participants", params: invalid.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 on duplicate document" do
      create(:participant, document: "12.345.678/0001-90")
      post "/api/v1/participants", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/participants/:id/kyc_check" do
    let(:participant) { create(:participant) }

    before do
      service = instance_double(KycCheckService)
      allow(KycCheckService).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_return(
        double(success?: true, value!: participant.tap { |p| p.update_column(:kyc_status, "approved") })
      )
    end

    it "returns 401 without auth" do
      post "/api/v1/participants/#{participant.id}/kyc_check"
      expect(response).to have_http_status(:unauthorized)
    end

    it "calls the KYC service and returns the updated participant" do
      post "/api/v1/participants/#{participant.id}/kyc_check", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]["attributes"]["kyc_status"]).to eq("approved")
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
