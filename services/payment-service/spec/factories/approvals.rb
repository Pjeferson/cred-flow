# frozen_string_literal: true

FactoryBot.define do
  factory :approval do
    association :payment_order, factory: %i[payment_order pending_approval]
    approver_id { SecureRandom.uuid }
    decision    { "APPROVED" }

    trait :rejected do
      decision { "REJECTED" }
    end
  end
end
