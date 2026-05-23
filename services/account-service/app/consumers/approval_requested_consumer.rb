# frozen_string_literal: true

class ApprovalRequestedConsumer < ApplicationConsumer
  from_queue "q.notifications.email",
             exchange:      "credflow.events",
             exchange_type: :topic,
             routing_key:   "approval.requested",
             durable:       true,
             arguments:     { "x-dead-letter-exchange" => "credflow.dlx",
                              "x-dead-letter-routing-key" => "dead" }

  private

  def handle(envelope)
    payload = envelope[:payload]

    account = Account.includes(:credor).find_by(id: payload[:accountId])
    return Rails.logger.warn("[ApprovalRequestedConsumer] Account #{payload[:accountId]} not found") unless account

    recipient = account.credor.email.presence || "credflow-approvals@example.com"

    NotificationMailer.approval_requested(
      payment_order_id:   payload[:paymentOrderId],
      account_id:         payload[:accountId],
      amount_cents:       payload[:amountCents],
      reason:             payload[:reason],
      approvers_needed:   payload[:approversNeeded],
      approvals_received: payload[:approvalsReceived],
      expires_at:         payload[:expiresAt],
      beneficiary_doc:    payload[:beneficiaryDoc],
      to:                 recipient
    ).deliver_now
  end
end
