# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/accounts" do
    it "returns 401 without auth" do
      get "/api/v1/accounts"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns an empty list when no accounts exist" do
      get "/api/v1/accounts", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]).to eq([])
    end

    it "returns all accounts" do
      create_list(:account, 2)
      get "/api/v1/accounts", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(2)
    end
  end

  describe "GET /api/v1/accounts/:id" do
    let(:account) { create(:account) }

    it "returns 401 without auth" do
      get "/api/v1/accounts/#{account.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the account with participant names" do
      get "/api/v1/accounts/#{account.id}", headers: headers
      expect(response).to have_http_status(:ok)
      attrs = json_body["data"]["attributes"]
      expect(attrs["type"]).to eq("empresa")
      expect(attrs["status"]).to eq("active")
      expect(attrs["cedente_name"]).to eq(account.cedente.name)
      expect(attrs["credor_name"]).to eq(account.credor.name)
    end

    it "returns 404 for unknown id" do
      get "/api/v1/accounts/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/accounts" do
    let(:cedente) { create(:participant, :kyc_approved, :cedente) }
    let(:credor)  { create(:participant, :kyc_approved, :credor) }

    let(:valid_params) do
      {
        account: {
          type:       "empresa",
          cedente_id: cedente.id,
          credor_id:  credor.id,
          policy_rules: { approval_threshold: { required: 1, of: 1 } }
        }
      }
    end

    it "returns 401 without auth" do
      post "/api/v1/accounts", params: valid_params.to_json, headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a empresa account with valid params" do
      post "/api/v1/accounts", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      attrs = json_body["data"]["attributes"]
      expect(attrs["type"]).to eq("empresa")
      expect(attrs["status"]).to eq("active")
    end

    it "creates an escrow account when sacado_id is provided" do
      sacado = create(:participant, :kyc_approved, :sacado)
      params = valid_params.deep_merge(account: { type: "escrow", sacado_id: sacado.id })
      post "/api/v1/accounts", params: params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(json_body["data"]["attributes"]["type"]).to eq("escrow")
    end

    it "returns 422 when escrow type has no sacado" do
      params = valid_params.deep_merge(account: { type: "escrow" })
      post "/api/v1/accounts", params: params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when cedente has no KYC approval" do
      pending_cedente = create(:participant, :cedente)
      params = valid_params.deep_merge(account: { cedente_id: pending_cedente.id })
      post "/api/v1/accounts", params: params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when credor has no KYC approval" do
      pending_credor = create(:participant, :credor)
      params = valid_params.deep_merge(account: { credor_id: pending_credor.id })
      post "/api/v1/accounts", params: params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/accounts/:id/balance" do
    let(:account) { create(:account) }

    it "returns 401 without auth" do
      get "/api/v1/accounts/#{account.id}/balance"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns zeros for an account with no ledger entries" do
      get "/api/v1/accounts/#{account.id}/balance", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["balance_cents"]).to eq(0)
      expect(json_body["available_cents"]).to eq(0)
      expect(json_body["account_id"]).to eq(account.id)
    end

    it "reflects settled credits in balance and available" do
      create(:ledger_entry, :credit_received, account: account, amount_cents: 500_000)
      get "/api/v1/accounts/#{account.id}/balance", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["balance_cents"]).to eq(500_000)
      expect(json_body["available_cents"]).to eq(500_000)
    end

    it "reduces available_cents for pending debit reserves" do
      create(:ledger_entry, :credit_received, account: account, amount_cents: 500_000)
      create(:ledger_entry, :debit_reserved,  account: account, amount_cents: 150_000,
             idempotency_key: "reserve-1")
      get "/api/v1/accounts/#{account.id}/balance", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["balance_cents"]).to eq(500_000)
      expect(json_body["available_cents"]).to eq(350_000)
    end

    it "reduces balance_cents for settled debits" do
      create(:ledger_entry, :credit_received, account: account, amount_cents: 500_000)
      create(:ledger_entry, :debit_executed,  account: account, amount_cents: 200_000,
             idempotency_key: "exec-1")
      get "/api/v1/accounts/#{account.id}/balance", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["balance_cents"]).to eq(300_000)
      expect(json_body["available_cents"]).to eq(300_000)
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
