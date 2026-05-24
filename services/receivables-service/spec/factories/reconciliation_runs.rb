# frozen_string_literal: true

FactoryBot.define do
  factory :reconciliation_run do
    account_id        { SecureRandom.uuid }
    sequence(:reference_date) { |n| Date.current - n.days }
    status            { "completed" }
    entries_checked   { 10 }
    divergences_found { 0 }
    ran_at            { 1.hour.ago }
    finished_at       { 30.minutes.ago }

    trait :with_divergences do
      divergences_found { 2 }
    end

    trait :failed do
      status        { "failed" }
      error_message { "spb_unavailable" }
      finished_at   { 45.minutes.ago }
    end
  end
end
