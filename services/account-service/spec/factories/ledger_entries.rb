# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_entry do
    association :account
    type          { "CREDIT_RECEIVED" }
    direction     { "CREDIT" }
    amount_cents  { 100_000 }
    status        { "SETTLED" }
    sequence(:idempotency_key) { |n| "idem-key-#{n}" }

    trait :credit_received do
      type      { "CREDIT_RECEIVED" }
      direction { "CREDIT" }
    end

    trait :debit_executed do
      type      { "DEBIT_EXECUTED" }
      direction { "DEBIT" }
      status    { "SETTLED" }
    end

    trait :debit_reserved do
      type      { "DEBIT_RESERVED" }
      direction { "DEBIT" }
      status    { "PENDING" }
    end
  end
end
