# frozen_string_literal: true

class CreatePaymentOrderService
  include Dry::Monads[:result]

  APPROVAL_TTL = 1.hour

  def call(account_id:, requested_by:, amount_cents:, beneficiary_doc:, beneficiary_name: nil, idempotency_key:)
    account_result = AccountServiceClient.new.fetch_account(account_id)
    return Failure({ error: "account_not_found", status: :not_found }) unless account_result.success?

    policy_rules = account_result.value![:policy_rules] || {}

    order = PaymentOrder.new(
      account_id:, requested_by:, amount_cents:,
      beneficiary_doc:, beneficiary_name:, idempotency_key:
    )
    return Failure({ errors: order.errors.full_messages }) unless order.save

    order.start_policy_check!
    decision = PolicyEngine.call(payment_order: order, policy_rules: policy_rules)
    order.update_columns(policy_action: decision.action.to_s)

    case decision.action
    when :rejected
      order.update_columns(rejection_reason: decision.reason)
      order.reject!

    when :pending_approval
      threshold = (policy_rules.dig("approval_threshold") || {}).symbolize_keys
      order.update_columns(expires_at: APPROVAL_TTL.from_now)
      order.pend_approval!

      EventPublisher.publish(
        "approval.requested",
        {
          paymentOrderId:    order.id,
          accountId:         order.account_id,
          amountCents:       order.amount_cents,
          reason:            decision.reason,
          approversNeeded:   threshold[:required] || 1,
          approvalsReceived: 0,
          expiresAt:         order.expires_at.iso8601,
          beneficiaryDoc:    order.beneficiary_doc
        },
        correlation_id: SecureRandom.uuid
      )

    when :scheduled
      order.update_columns(scheduled_for: next_allowed_time(policy_rules))
      order.schedule!

    when :execute
      order.approve!
      return ExecutePaymentService.new.call(order)
    end

    Success(order.reload)
  end

  private

  def next_allowed_time(policy_rules)
    blocked  = (policy_rules["blocked_hours"] || {}).symbolize_keys
    end_h, end_m = blocked[:end].to_s.split(":").map(&:to_i)
    Time.current.tomorrow.beginning_of_day.change(hour: end_h, min: end_m)
  rescue
    1.hour.from_now
  end
end
