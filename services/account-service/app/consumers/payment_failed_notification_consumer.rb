# frozen_string_literal: true

class PaymentFailedNotificationConsumer < ApplicationConsumer
  from_queue "q.notifications.email",
             exchange:      "credflow.events",
             exchange_type: :topic,
             routing_key:   "payment.failed",
             durable:       true,
             arguments:     { "x-dead-letter-exchange" => "credflow.dlx",
                              "x-dead-letter-routing-key" => "dead" }

  private

  def handle(envelope)
    payload = envelope[:payload]

    account = Account.includes(:cedente).find_by(id: payload[:accountId])
    return Rails.logger.warn("[PaymentFailedNotificationConsumer] Account #{payload[:accountId]} not found") unless account

    recipient = account.cedente.email.presence || "credflow-notifications@example.com"

    NotificationMailer.payment_failed(
      payment_order_id: payload[:paymentOrderId],
      account_id:       payload[:accountId],
      amount_cents:     payload[:amountCents],
      reason:           payload[:reason],
      to:               recipient
    ).deliver_now
  end
end
