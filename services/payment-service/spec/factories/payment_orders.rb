# frozen_string_literal: true

FactoryBot.define do
  factory :payment_order do
    account_id      { SecureRandom.uuid }
    requested_by    { SecureRandom.uuid }
    amount_cents    { 100_000 }
    beneficiary_doc { "12.345.678/0001-90" }
    sequence(:idempotency_key) { |n| "idem-#{n}" }

    trait :pending_approval do
      after(:create) { |o| o.update_column(:status, "pending_approval") }
    end

    trait :settled do
      after(:create) { |o| o.update_column(:status, "settled") }
    end

    trait :rejected do
      after(:create) { |o| o.update_column(:status, "rejected") }
    end
  end
end
