# frozen_string_literal: true

class ExpirePendingApprovalsJob < ApplicationJob
  queue_as :default

  def perform
    expired_orders = PaymentOrder.where(status: "pending_approval")
                                 .where("expires_at <= ?", Time.current)

    expired_orders.find_each do |order|
      order.expire!
      EventPublisher.publish(
        "payment.approval_expired",
        {
          paymentOrderId: order.id,
          accountId:      order.account_id,
          amountCents:    order.amount_cents,
          expiredAt:      order.expires_at&.iso8601
        },
        correlation_id: SecureRandom.uuid
      )
    rescue AASM::InvalidTransition => e
      Rails.logger.warn("[ExpirePendingApprovalsJob] Skipping order #{order.id}: #{e.message}")
    end
  end
end
