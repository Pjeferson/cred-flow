# frozen_string_literal: true

class PaymentOrder < ApplicationRecord
  include AASM

  STATUSES = %w[
    draft policy_check pending_approval scheduled
    approved executing settled rejected failed expired
  ].freeze

  has_many :approvals, dependent: :destroy

  validates :account_id,      presence: true
  validates :requested_by,    presence: true
  validates :amount_cents,    presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :beneficiary_doc, presence: true
  validates :idempotency_key, presence: true, uniqueness: true
  validates :status,          inclusion: { in: STATUSES }

  aasm column: :status, no_direct_assignment: true do
    state :draft, initial: true
    state :policy_check
    state :pending_approval
    state :scheduled
    state :approved
    state :executing
    state :settled
    state :rejected
    state :failed
    state :expired

    event :start_policy_check do
      transitions from: :draft, to: :policy_check
    end

    event :pend_approval do
      transitions from: :policy_check, to: :pending_approval
    end

    event :schedule do
      transitions from: :policy_check, to: :scheduled
    end

    event :approve do
      transitions from: %i[pending_approval policy_check], to: :approved
    end

    event :reject do
      transitions from: :pending_approval, to: :rejected
    end

    event :expire do
      transitions from: :pending_approval, to: :expired
    end

    event :start_execution do
      transitions from: %i[approved scheduled], to: :executing
    end

    event :settle do
      transitions from: :executing, to: :settled
      after { update_columns(settled_at: Time.current) }
    end

    event :fail do
      transitions from: :executing, to: :failed
    end
  end

  after_save :log_status_change, if: :saved_change_to_status?

  private

  def log_status_change
    prev, curr = saved_change_to_status
    Rails.logger.info(
      "[PaymentOrder] #{id} status: #{prev} → #{curr}"
    )
  end
end
