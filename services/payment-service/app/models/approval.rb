# frozen_string_literal: true

class Approval < ApplicationRecord
  DECISIONS = %w[APPROVED REJECTED].freeze

  belongs_to :payment_order

  validates :approver_id, presence: true
  validates :decision,    presence: true, inclusion: { in: DECISIONS }
  validates :approver_id, uniqueness: { scope: :payment_order_id,
    message: "já registrou uma decisão para esta ordem" }

  before_update  { raise ActiveRecord::ReadOnlyRecord, "Approval é append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Approval é append-only" }

  scope :approved,  -> { where(decision: "APPROVED") }
  scope :rejected,  -> { where(decision: "REJECTED") }
end
