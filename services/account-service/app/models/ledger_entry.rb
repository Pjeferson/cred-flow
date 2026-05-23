# frozen_string_literal: true

class LedgerEntry < ApplicationRecord
  # 'type' é tipo de lançamento, não STI
  self.inheritance_column = nil

  TYPES = %w[
    CREDIT_ANTECIPATION
    CREDIT_RECEIVED
    DEBIT_RESERVED
    DEBIT_EXECUTED
    DEBIT_REVERSED
  ].freeze

  DIRECTIONS = %w[CREDIT DEBIT].freeze
  STATUSES   = %w[SETTLED PENDING REVERSED].freeze

  DIRECTION_BY_TYPE = {
    "CREDIT_ANTECIPATION" => "CREDIT",
    "CREDIT_RECEIVED"     => "CREDIT",
    "DEBIT_RESERVED"      => "DEBIT",
    "DEBIT_EXECUTED"      => "DEBIT",
    "DEBIT_REVERSED"      => "DEBIT"
  }.freeze

  belongs_to :account

  validates :type,            presence: true, inclusion: { in: TYPES }
  validates :direction,       presence: true, inclusion: { in: DIRECTIONS }
  validates :amount_cents,    presence: true, numericality: { greater_than: 0 }
  validates :status,          inclusion: { in: STATUSES }
  validates :idempotency_key, presence: true

  # Ledger é append-only — UPDATE e DELETE são proibidos
  before_update  { raise ActiveRecord::ReadOnlyRecord, "LedgerEntry is append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "LedgerEntry is append-only" }
end
