# frozen_string_literal: true

class BalanceCalculator
  Result = Data.define(:balance_cents, :available_cents)

  def self.call(account_id:)
    new(account_id).call
  end

  def initialize(account_id)
    @account_id = account_id
  end

  def call
    Result.new(
      balance_cents:   compute(status: %w[SETTLED]),
      available_cents: compute(status: %w[SETTLED PENDING])
    )
  end

  private

  BALANCE_SQL = <<~SQL.squish.freeze
    COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_cents ELSE -amount_cents END), 0)
  SQL

  def compute(status:)
    LedgerEntry
      .where(account_id: @account_id, status: status)
      .pick(Arel.sql(BALANCE_SQL))
      .to_i
  end
end
