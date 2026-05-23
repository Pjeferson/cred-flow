# frozen_string_literal: true

class ApprovalSerializer
  include JSONAPI::Serializer

  set_type :approval

  attributes :payment_order_id, :approver_id, :decision, :decided_at
end
