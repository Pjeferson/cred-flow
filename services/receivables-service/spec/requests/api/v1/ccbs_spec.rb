# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CCBs", type: :request do
  let(:headers)    { auth_headers }
  let(:account_id) { SecureRandom.uuid }

  describe "GET /api/v1/ccbs" do
    it "returns 401 without auth" do
      get "/api/v1/ccbs"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns an empty list when no CCBs exist" do
      get "/api/v1/ccbs", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]).to eq([])
    end

    it "returns all CCBs ordered by issued_at desc" do
      create_list(:ccb, 3)
      get "/api/v1/ccbs", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(3)
    end

    it "filters by account_id" do
      ccb = create(:ccb, account_id: account_id)
      create(:ccb)
      get "/api/v1/ccbs", params: { account_id: account_id }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(1)
      expect(json_body["data"][0]["id"]).to eq(ccb.id)
    end
  end

  describe "GET /api/v1/ccbs/:id" do
    it "returns 401 without auth" do
      ccb = create(:ccb)
      get "/api/v1/ccbs/#{ccb.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the CCB with installments in the included array" do
      ccb = create(:ccb, :with_installments, installment_count: 3)
      get "/api/v1/ccbs/#{ccb.id}", headers: headers
      expect(response).to have_http_status(:ok)
      attrs = json_body["data"]["attributes"]
      expect(attrs["principal_cents"]).to eq(120_000)
      expect(attrs["installment_count"]).to eq(3)
      expect(attrs["status"]).to eq("active")
      expect(json_body["included"].length).to eq(3)
      expect(json_body["included"].map { _1["type"] }.uniq).to eq(["installment"])
    end

    it "returns installments summing to principal_cents (residual absorbed by last)" do
      ccb = create(:ccb, :with_installments, principal_cents: 100_003, installment_count: 3)
      get "/api/v1/ccbs/#{ccb.id}", headers: headers
      total = json_body["included"].sum { _1["attributes"]["amount_cents"] }
      expect(total).to eq(100_003)
    end

    it "returns 404 for unknown id" do
      get "/api/v1/ccbs/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/ccbs" do
    let(:valid_params) do
      {
        ccb: {
          account_id:        account_id,
          principal_cents:   240_000,
          discount_cents:    12_000,
          annual_rate:       "0.12",
          installment_count: 6,
          first_due_date:    Date.current.next_month.iso8601
        }
      }
    end

    it "returns 401 without auth" do
      post "/api/v1/ccbs", params: valid_params.to_json, headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a CCB and its installments in one transaction" do
      post "/api/v1/ccbs", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:created)

      attrs = json_body["data"]["attributes"]
      expect(attrs["principal_cents"]).to eq(240_000)
      expect(attrs["discount_cents"]).to eq(12_000)
      expect(attrs["net_cents"]).to eq(228_000)
      expect(attrs["installment_count"]).to eq(6)
      expect(attrs["status"]).to eq("active")
      expect(json_body["included"].length).to eq(6)
    end

    it "ensures installments sum to principal_cents" do
      post "/api/v1/ccbs", params: valid_params.to_json, headers: headers
      total = json_body["included"].sum { _1["attributes"]["amount_cents"] }
      expect(total).to eq(240_000)
    end

    it "returns 422 when required fields are missing" do
      post "/api/v1/ccbs",
           params:  { ccb: { account_id: account_id } }.to_json,
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when principal_cents is zero or negative" do
      params = valid_params.deep_merge(ccb: { principal_cents: 0 })
      post "/api/v1/ccbs", params: params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
