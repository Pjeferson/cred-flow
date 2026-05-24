# frozen_string_literal: true

class ProcessApprovalService
  include Dry::Monads[:result]

  def call(payment_order:, approver_id:, decision:, ip_address: nil, user_agent: nil)
    return Failure("order_not_approvable") unless payment_order.pending_approval?

    approval = Approval.new(
      payment_order:, approver_id:, decision:, ip_address:, user_agent:
    )
    return Failure(approval.errors.full_messages.join(", ")) unless approval.save

    if decision == "REJECTED"
      payment_order.reject!
      payment_order.update_columns(rejection_reason: "approver_rejected")
      publish_failed(payment_order, nil)
      return Success({ order: payment_order.reload, approval: })
    end

    policy_rules  = fetch_policy_rules(payment_order.account_id)
    threshold_cfg = policy_rules.dig(:approval_threshold) || {}
    required      = (threshold_cfg[:required] || 1).to_i

    if payment_order.approvals.approved.count >= required
      payment_order.approve!
      result = ExecutePaymentService.new.call(payment_order)
      return result.success? ? Success({ order: result.value!, approval: }) : result
    end

    Success({ order: payment_order.reload, approval: })
  rescue ActiveRecord::RecordNotUnique
    Failure("approver_already_decided")
  rescue AASM::InvalidTransition => e
    Failure("invalid_transition: #{e.message}")
  end

  private

  def fetch_policy_rules(account_id)
    result = AccountServiceClient.new.fetch_account(account_id)
    result.success? ? (result.value![:policy_rules] || {}) : {}
  end

  def publish_failed(order, reserved_entry_id)
    EventPublisher.publish(
      "payment.failed",
      {
        paymentOrderId:  order.id,
        accountId:       order.account_id,
        amountCents:     order.amount_cents,
        reason:          order.rejection_reason,
        reservedEntryId: reserved_entry_id
      },
      correlation_id: SecureRandom.uuid
    )
  end
end
