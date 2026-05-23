# frozen_string_literal: true

class CcbSerializer
  include JSONAPI::Serializer

  set_type :ccb

  attributes :account_id, :principal_cents, :discount_cents, :net_cents,
             :annual_rate, :installment_count, :first_due_date,
             :status, :issued_at, :settled_at

  has_many :installments, serializer: InstallmentSerializer
end
