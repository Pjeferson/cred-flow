# frozen_string_literal: true

require "rails_helper"

RSpec.describe PolicyEngine, type: :service do
  let(:account_id) { SecureRandom.uuid }

  def build_order(amount_cents: 10_000, beneficiary_doc: "12.345.678/0001-90")
    create(:payment_order, account_id: account_id,
                           amount_cents: amount_cents,
                           beneficiary_doc: beneficiary_doc)
  end

  def run(order, rules = {})
    PolicyEngine.call(payment_order: order, policy_rules: rules)
  end

  describe "execute path" do
    it "returns :execute when no rules are configured" do
      result = run(build_order)
      expect(result.action).to eq(:execute)
      expect(result.reason).to be_nil
    end

    it "returns :execute when amount is below threshold" do
      result = run(build_order(amount_cents: 40_000),
                   { "approval_required_above_cents" => 50_000 })
      expect(result.action).to eq(:execute)
    end
  end

  describe "pending_approval — amount threshold" do
    it "returns :pending_approval when amount exceeds threshold" do
      result = run(build_order(amount_cents: 60_000),
                   { "approval_required_above_cents" => 50_000 })
      expect(result.action).to eq(:pending_approval)
      expect(result.reason).to eq("amount_threshold")
    end

    it "returns :execute when amount equals threshold (not above)" do
      result = run(build_order(amount_cents: 50_000),
                   { "approval_required_above_cents" => 50_000 })
      expect(result.action).to eq(:execute)
    end
  end

  describe "pending_approval — new beneficiary" do
    let(:doc) { "98.765.432/0001-10" }
    let(:rules) { { "new_beneficiary_requires_approval" => true } }

    it "returns :pending_approval for a beneficiary with no prior settled orders" do
      result = run(build_order(beneficiary_doc: doc), rules)
      expect(result.action).to eq(:pending_approval)
      expect(result.reason).to eq("new_beneficiary")
    end

    it "returns :execute when beneficiary has a prior settled order" do
      create(:payment_order, :settled, account_id: account_id, beneficiary_doc: doc)
      result = run(build_order(beneficiary_doc: doc), rules)
      expect(result.action).to eq(:execute)
    end
  end

  describe "rejected — daily limit exceeded" do
    it "returns :rejected when today's total exceeds the daily limit" do
      # Two prior orders totalling 180_000, limit is 200_000, new order = 30_000 → 210_000 > 200_000
      create(:payment_order, account_id: account_id, amount_cents: 90_000,
             idempotency_key: "prior-1")
      create(:payment_order, account_id: account_id, amount_cents: 90_000,
             idempotency_key: "prior-2")

      order  = build_order(amount_cents: 30_000)
      result = run(order, { "daily_limit_cents" => 200_000 })
      expect(result.action).to eq(:rejected)
      expect(result.reason).to eq("daily_limit_exceeded")
    end

    it "returns :execute when total stays within the limit" do
      create(:payment_order, account_id: account_id, amount_cents: 50_000,
             idempotency_key: "prior-1")

      order  = build_order(amount_cents: 50_000)
      result = run(order, { "daily_limit_cents" => 200_000 })
      expect(result.action).to eq(:execute)
    end
  end

  describe "scheduled — outside allowed hours" do
    let(:rules) { { "blocked_hours" => { "start" => "22:00", "end" => "06:00" } } }

    it "returns :scheduled when current time is in the blocked window" do
      travel_to Time.zone.local(2024, 1, 15, 23, 30) do
        result = run(build_order, rules)
        expect(result.action).to eq(:scheduled)
        expect(result.reason).to eq("outside_allowed_hours")
      end
    end

    it "returns :execute when current time is outside the blocked window" do
      travel_to Time.zone.local(2024, 1, 15, 12, 0) do
        result = run(build_order, rules)
        expect(result.action).to eq(:execute)
      end
    end
  end
end
