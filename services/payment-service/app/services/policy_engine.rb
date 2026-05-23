# frozen_string_literal: true

class PolicyEngine
  Result = Data.define(:action, :reason)

  def self.call(payment_order:, policy_rules:)
    new(payment_order, policy_rules).call
  end

  def initialize(payment_order, policy_rules)
    @order = payment_order
    @rules = (policy_rules || {}).deep_symbolize_keys
  end

  def call
    return Result.new(action: :rejected,        reason: "daily_limit_exceeded")  if daily_limit_exceeded?
    return Result.new(action: :pending_approval, reason: "amount_threshold")      if above_threshold?
    return Result.new(action: :pending_approval, reason: "new_beneficiary")       if new_beneficiary?
    return Result.new(action: :scheduled,        reason: "outside_allowed_hours") if outside_hours?

    Result.new(action: :execute, reason: nil)
  end

  private

  def daily_limit_exceeded?
    limit = @rules[:daily_limit_cents]
    return false unless limit

    daily_total = PaymentOrder
      .where(account_id: @order.account_id)
      .where(status: %w[draft policy_check pending_approval approved executing settled])
      .where("created_at >= ?", Time.current.beginning_of_day)
      .where.not(id: @order.id)
      .sum(:amount_cents)

    daily_total + @order.amount_cents > limit
  end

  def above_threshold?
    threshold = @rules[:approval_required_above_cents]
    return false unless threshold

    @order.amount_cents > threshold
  end

  def new_beneficiary?
    return false unless @rules[:new_beneficiary_requires_approval]

    !PaymentOrder
      .where(account_id: @order.account_id, beneficiary_doc: @order.beneficiary_doc, status: "settled")
      .exists?
  end

  def outside_hours?
    blocked = @rules[:blocked_hours]
    return false unless blocked

    start_h, start_m = blocked[:start].to_s.split(":").map(&:to_i)
    end_h,   end_m   = blocked[:end].to_s.split(":").map(&:to_i)

    now         = Time.current
    current_min = now.hour * 60 + now.min
    start_min   = start_h * 60 + start_m
    end_min     = end_h   * 60 + end_m

    # Janela overnight (ex: 17:00–09:00)
    if start_min > end_min
      current_min >= start_min || current_min < end_min
    else
      current_min.between?(start_min, end_min - 1)
    end
  end
end
