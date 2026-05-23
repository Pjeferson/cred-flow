# frozen_string_literal: true

class LedgerEntrySerializer
  include JSONAPI::Serializer

  set_type :ledger_entry

  attributes :type, :direction, :amount_cents, :status,
             :payment_order_id, :idempotency_key, :description, :created_at
  attribute  :account_id
end
