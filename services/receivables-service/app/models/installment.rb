# frozen_string_literal: true

class Installment < ApplicationRecord
  STATUSES = %w[pending partially_paid paid overdue].freeze

  belongs_to :ccb

  validates :number, :amount_cents, :due_date, presence: true
  validates :amount_cents, numericality: { greater_than: 0, only_integer: true }
  validates :paid_cents,   numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :status,       inclusion: { in: STATUSES }
  validates :number,       uniqueness: { scope: :ccb_id }

  scope :pending,        -> { where(status: "pending") }
  scope :partially_paid, -> { where(status: "partially_paid") }
  scope :overdue,        -> { where(status: "overdue") }
  scope :unpaid,         -> { where(status: %w[pending partially_paid]) }
  scope :due_on_or_before, ->(date) { where(due_date: ..date) }
end
