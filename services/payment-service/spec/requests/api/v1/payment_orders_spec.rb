# frozen_string_literal: true

require "rails_helper"
include Dry::Monads[:result]

RSpec.describe "PaymentOrders", type: :request do
  let(:headers) { auth_headers }

  # Stubs compartilhados para isolar dependências externas
  let(:account_id)     { SecureRandom.uuid }
  let(:policy_rules)   { { "approval_required_above_cents" => 50_000 } }
  let(:account_client) { instance_double(AccountServiceClient) }

  before do
    allow(AccountServiceClient).to receive(:new).and_return(account_client)
    allow(account_client).to receive(:fetch_account)
      .and_return(Success({ policy_rules: policy_rules }))
    allow(EventPublisher).to receive(:publish)
  end

  describe "GET /api/v1/payment_orders" do
    it "returns 401 without auth" do
      get "/api/v1/payment_orders"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns an empty list" do
      get "/api/v1/payment_orders", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]).to eq([])
    end

    it "returns all payment orders" do
      create_list(:payment_order, 3)
      get "/api/v1/payment_orders", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(3)
    end

    it "filters by account_id" do
      order = create(:payment_order, account_id: account_id)
      create(:payment_order)
      get "/api/v1/payment_orders", params: { account_id: account_id }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(1)
      expect(json_body["data"][0]["id"]).to eq(order.id)
    end

    it "filters by status" do
      create(:payment_order, :pending_approval)
      create(:payment_order, :settled)
      get "/api/v1/payment_orders", params: { status: "settled" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(1)
      expect(json_body["data"][0]["attributes"]["status"]).to eq("settled")
    end
  end

  describe "GET /api/v1/payment_orders/:id" do
    let(:order) { create(:payment_order) }

    it "returns 401 without auth" do
      get "/api/v1/payment_orders/#{order.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the payment order" do
      get "/api/v1/payment_orders/#{order.id}", headers: headers
      expect(response).to have_http_status(:ok)
      attrs = json_body["data"]["attributes"]
      expect(attrs["status"]).to eq("draft")
      expect(attrs["amount_cents"]).to eq(100_000)
    end

    it "returns 404 for unknown id" do
      get "/api/v1/payment_orders/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/payment_orders" do
    let(:valid_params) do
      {
        payment_order: {
          account_id:      account_id,
          requested_by:    SecureRandom.uuid,
          amount_cents:    80_000,
          beneficiary_doc: "12.345.678/0001-90"
        }
      }
    end
    let(:idem_headers) { headers.merge("Idempotency-Key" => SecureRandom.uuid) }

    it "returns 401 without auth" do
      post "/api/v1/payment_orders", params: valid_params.to_json, headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 422 when Idempotency-Key header is missing" do
      post "/api/v1/payment_orders", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["error"]).to match(/Idempotency-Key/i)
    end

    it "returns 404 when account does not exist" do
      allow(account_client).to receive(:fetch_account).and_return(Failure("not_found"))
      post "/api/v1/payment_orders", params: valid_params.to_json, headers: idem_headers
      expect(response).to have_http_status(:not_found)
    end

    context "when amount is above the approval threshold" do
      let(:policy_rules) { { "approval_required_above_cents" => 50_000 } }

      it "creates the order in pending_approval state" do
        post "/api/v1/payment_orders",
             params:  valid_params.deep_merge(payment_order: { amount_cents: 80_000 }).to_json,
             headers: idem_headers

        expect(response).to have_http_status(:created)
        expect(json_body["data"]["attributes"]["status"]).to eq("pending_approval")
        expect(json_body["data"]["attributes"]["policy_action"]).to eq("pending_approval")
        expect(EventPublisher).to have_received(:publish).with("approval.requested", anything, anything)
      end
    end

    context "when policy allows immediate execution" do
      let(:policy_rules) { {} }

      before do
        # Stub the ledger reservation and SPB call inside ExecutePaymentService
        allow(account_client).to receive(:create_ledger_entry)
          .and_return(Success(SecureRandom.uuid))
        allow_any_instance_of(ExecutePaymentService).to receive(:call_spb)
          .and_return({ status: "settled", spb_transaction_id: "spb-abc" })
      end

      it "creates the order and settles it immediately" do
        post "/api/v1/payment_orders",
             params:  valid_params.deep_merge(payment_order: { amount_cents: 10_000 }).to_json,
             headers: idem_headers

        expect(response).to have_http_status(:created)
        expect(json_body["data"]["attributes"]["status"]).to eq("settled")
        expect(EventPublisher).to have_received(:publish).with("payment.settled", anything, anything)
      end
    end

    context "idempotency" do
      it "returns the same response for duplicate Idempotency-Key" do
        key = SecureRandom.uuid
        headers_with_key = headers.merge("Idempotency-Key" => key)

        post "/api/v1/payment_orders", params: valid_params.to_json, headers: headers_with_key
        first_body = response.body

        post "/api/v1/payment_orders", params: valid_params.to_json, headers: headers_with_key
        expect(response).to have_http_status(:created)
        expect(response.body).to eq(first_body)
      end
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
