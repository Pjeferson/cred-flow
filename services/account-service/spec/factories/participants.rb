# frozen_string_literal: true

FactoryBot.define do
  factory :participant do
    sequence(:name)     { |n| "Participante #{n}" }
    sequence(:document) { |n| format("%03d.456.%03d-%02d", n, (n * 7 % 999) + 1, (n % 98) + 1) }
    sequence(:email)    { |n| "participante#{n}@example.com" }
    role       { "cedente" }
    kyc_status { "pending" }

    trait :kyc_approved do
      kyc_status { "approved" }
    end

    trait :kyc_rejected do
      kyc_status { "rejected" }
    end

    trait :cedente do
      role { "cedente" }
    end

    trait :credor do
      role { "credor" }
    end

    trait :sacado do
      role { "sacado" }
    end
  end
end
