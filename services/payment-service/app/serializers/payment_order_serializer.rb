# frozen_string_literal: true

class PaymentOrderSerializer
  include JSONAPI::Serializer

  set_type :payment_order

  attributes :account_id, :requested_by, :amount_cents,
             :beneficiary_doc, :beneficiary_name, :status,
             :policy_action, :rejection_reason, :spb_transaction_id,
             :idempotency_key, :scheduled_for, :expires_at,
             :executed_at, :settled_at, :created_at
end
