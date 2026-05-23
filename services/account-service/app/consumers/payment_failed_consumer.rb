# frozen_string_literal: true

class PaymentFailedConsumer < ApplicationConsumer
  from_queue "account-service.payment.failed",
             exchange: "credflow.events",
             exchange_type: :topic,
             routing_key: "payment.failed",
             durable: true,
             arguments: { "x-dead-letter-exchange" => "credflow.dlx" }

  private

  def handle(envelope)
    payload = envelope[:payload]

    LedgerWriterService.new.call(
      account_id:       payload[:accountId],
      type:             "DEBIT_REVERSED",
      amount_cents:     payload[:amountCents],
      payment_order_id: payload[:paymentOrderId],
      idempotency_key:  "debit_reversed:#{payload[:paymentOrderId]}",
      status:           "SETTLED",
      description:      "Estorno de reserva — #{payload[:reason]}"
    )
  end
end
