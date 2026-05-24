# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    association :cedente, factory: %i[participant kyc_approved cedente]
    association :credor,  factory: %i[participant kyc_approved credor]
    sacado { nil }
    type         { "empresa" }
    policy_rules { { "approval_threshold" => { "required" => 1, "of" => 1 } } }

    trait :escrow do
      type { "escrow" }
      association :sacado, factory: %i[participant kyc_approved sacado]
    end
  end
end
