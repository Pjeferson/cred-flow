# frozen_string_literal: true

class PaymentSettledConsumer < ApplicationConsumer
  from_queue "account-service.payment.settled",
             exchange: "credflow.events",
             exchange_type: :topic,
             routing_key: "payment.settled",
             durable: true,
             arguments: { "x-dead-letter-exchange" => "credflow.dlx" }

  private

  def handle(envelope)
    payload = envelope[:payload]

    LedgerWriterService.new.call(
      account_id:       payload[:accountId],
      type:             "DEBIT_EXECUTED",
      amount_cents:     payload[:amountCents],
      payment_order_id: payload[:paymentOrderId],
      idempotency_key:  "debit_executed:#{payload[:paymentOrderId]}",
      status:           "SETTLED",
      description:      "Pagamento liquidado via SPB"
    )
  end
end
