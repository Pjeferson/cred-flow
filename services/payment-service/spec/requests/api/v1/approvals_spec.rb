# frozen_string_literal: true

require "rails_helper"
include Dry::Monads[:result]

RSpec.describe "Approvals", type: :request do
  let(:headers)     { auth_headers }
  let(:approver_id) { SecureRandom.uuid }

  let(:account_client) { instance_double(AccountServiceClient) }
  let(:policy_rules)   { { "approval_threshold" => { "required" => 1, "of" => 1 } } }

  before do
    allow(AccountServiceClient).to receive(:new).and_return(account_client)
    allow(account_client).to receive(:fetch_account)
      .and_return(Success({ policy_rules: policy_rules }))
    allow(account_client).to receive(:create_ledger_entry)
      .and_return(Success(SecureRandom.uuid))
    allow(EventPublisher).to receive(:publish)
  end

  describe "POST /api/v1/payment_orders/:payment_order_id/approvals" do
    let(:order) { create(:payment_order, :pending_approval) }

    let(:approval_params) do
      { approval: { approver_id: approver_id, decision: "APPROVED" } }
    end

    it "returns 401 without auth" do
      post "/api/v1/payment_orders/#{order.id}/approvals",
           params: approval_params.to_json, headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for unknown payment_order_id" do
      post "/api/v1/payment_orders/#{SecureRandom.uuid}/approvals",
           params: approval_params.to_json, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when order is not in pending_approval state" do
      settled_order = create(:payment_order, :settled)
      post "/api/v1/payment_orders/#{settled_order.id}/approvals",
           params: approval_params.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "APPROVED decision — quorum not yet reached" do
      let(:policy_rules) { { "approval_threshold" => { "required" => 2, "of" => 2 } } }

      it "records the approval and keeps order in pending_approval" do
        post "/api/v1/payment_orders/#{order.id}/approvals",
             params: approval_params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        order_attrs = json_body["order"]["data"]["attributes"]
        expect(order_attrs["status"]).to eq("pending_approval")
        expect(json_body["approval"]["data"]["attributes"]["decision"]).to eq("APPROVED")
      end
    end

    context "APPROVED decision — quorum reached (required=1)" do
      before do
        allow_any_instance_of(ExecutePaymentService).to receive(:call_spb)
          .and_return({ status: "settled", spb_transaction_id: "spb-xyz" })
      end

      it "triggers execution and returns settled order" do
        post "/api/v1/payment_orders/#{order.id}/approvals",
             params: approval_params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        expect(json_body["order"]["data"]["attributes"]["status"]).to eq("settled")
        expect(EventPublisher).to have_received(:publish).with("payment.settled", anything, anything)
      end
    end

    context "REJECTED decision" do
      let(:rejection_params) do
        { approval: { approver_id: approver_id, decision: "REJECTED" } }
      end

      it "rejects the order and publishes payment.failed" do
        post "/api/v1/payment_orders/#{order.id}/approvals",
             params: rejection_params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        expect(json_body["order"]["data"]["attributes"]["status"]).to eq("rejected")
        expect(EventPublisher).to have_received(:publish).with("payment.failed", anything, anything)
      end
    end

    context "duplicate approver" do
      it "returns 422 when the same approver tries to decide twice" do
        create(:approval, payment_order: order, approver_id: approver_id)

        post "/api/v1/payment_orders/#{order.id}/approvals",
             params: approval_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
