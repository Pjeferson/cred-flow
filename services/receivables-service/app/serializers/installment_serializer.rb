# frozen_string_literal: true

class InstallmentSerializer
  include JSONAPI::Serializer

  set_type :installment

  attributes :ccb_id, :number, :amount_cents, :paid_cents,
             :due_date, :paid_at, :status
end
