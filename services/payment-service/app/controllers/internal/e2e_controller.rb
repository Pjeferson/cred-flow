# frozen_string_literal: true

module Internal
  class E2eController < BaseController
    def seed
      unless Rails.env.test?
        render json: { error: "Disponível apenas em RAILS_ENV=test" }, status: :forbidden
        return
      end

      account_id = "11111111-2222-3333-4444-100000000001"
      requester  = "dd000000-0000-0000-0000-000000000001"

      ActiveRecord::Base.transaction do
        Approval.delete_all
        PaymentOrder.delete_all

        [
          { key: "e2e-po-001", amount: 250_000, doc: "67.890.123/0001-41", name: "Fornecedor E2E Alpha" },
          { key: "e2e-po-002", amount: 180_000, doc: "78.901.234/0001-50", name: "Fornecedor E2E Beta" }
        ].each do |attrs|
          order = PaymentOrder.create!(
            account_id: account_id, amount_cents: attrs[:amount],
            beneficiary_doc: attrs[:doc], beneficiary_name: attrs[:name],
            idempotency_key: attrs[:key], policy_action: "pending_approval",
            requested_by: requester, expires_at: 24.hours.from_now
          )
          order.update_column(:status, "pending_approval")
        end
      end

      render json: {
        ok: true,
        pending_orders: PaymentOrder.where(status: "pending_approval").count,
        approvals: Approval.count
      }
    end
  end
end
