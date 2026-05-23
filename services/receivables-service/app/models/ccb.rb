# frozen_string_literal: true

class Ccb < ApplicationRecord
  STATUSES = %w[active settled defaulted cancelled].freeze

  has_many :installments, dependent: :destroy

  validates :account_id, :principal_cents, :net_cents,
            :annual_rate, :installment_count, :first_due_date, presence: true
  validates :principal_cents,   numericality: { greater_than: 0, only_integer: true }
  validates :discount_cents,    numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :net_cents,         numericality: { greater_than: 0, only_integer: true }
  validates :installment_count, numericality: { greater_than: 0, only_integer: true }
  validates :status,            inclusion: { in: STATUSES }

  before_validation :compute_net_cents

  scope :active,    -> { where(status: "active") }
  scope :defaulted, -> { where(status: "defaulted") }

  private

  def compute_net_cents
    return unless principal_cents && discount_cents

    self.net_cents = principal_cents - discount_cents
  end
end
