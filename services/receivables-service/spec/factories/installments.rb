# frozen_string_literal: true

FactoryBot.define do
  factory :installment do
    association :ccb
    sequence(:number) { |n| n }
    amount_cents { 40_000 }
    paid_cents   { 0 }
    due_date     { 1.month.from_now.to_date }
    status       { "pending" }

    trait :overdue do
      status   { "overdue" }
      due_date { 1.month.ago.to_date }
    end

    trait :paid do
      status     { "paid" }
      paid_cents { 40_000 }
      paid_at    { Date.current }
    end

    trait :partially_paid do
      status     { "partially_paid" }
      paid_cents { 20_000 }
    end
  end
end
