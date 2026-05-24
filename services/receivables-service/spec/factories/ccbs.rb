# frozen_string_literal: true

FactoryBot.define do
  factory :ccb do
    account_id        { SecureRandom.uuid }
    principal_cents   { 120_000 }
    discount_cents    { 0 }
    annual_rate       { "0.12" }
    installment_count { 3 }
    first_due_date    { Date.current.next_month }

    trait :with_installments do
      after(:create) { |ccb| InstallmentScheduler.new.call(ccb) }
    end

    trait :defaulted do
      after(:create) { |ccb| ccb.update_column(:status, "defaulted") }
    end
  end
end
