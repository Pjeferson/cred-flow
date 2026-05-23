# frozen_string_literal: true

class PaymentSettledConsumer < ApplicationConsumer
  from_queue "q.receivables.events",
             exchange:      "credflow.events",
             exchange_type: :topic,
             routing_key:   "payment.settled",
             durable:       true,
             arguments:     { "x-dead-letter-exchange" => "credflow.dlx" }

  private

  def handle(envelope)
    payload    = envelope[:payload]
    account_id = payload[:accountId]
    remaining  = payload[:amountCents].to_i

    return if remaining <= 0

    installments = Installment
      .joins(:ccb)
      .where(ccbs: { account_id: account_id })
      .where(status: %w[pending partially_paid])
      .order("installments.due_date ASC, installments.number ASC")

    ActiveRecord::Base.transaction do
      installments.each do |installment|
        break if remaining <= 0

        remaining = apply_payment(installment, remaining, account_id)
      end
    end
  end

  def apply_payment(installment, remaining, account_id)
    owed    = installment.amount_cents - installment.paid_cents
    payment = [owed, remaining].min

    new_paid = installment.paid_cents + payment
    paid_off = new_paid >= installment.amount_cents

    installment.update!(
      paid_cents: new_paid,
      status:     paid_off ? "paid" : "partially_paid",
      paid_at:    paid_off ? Date.current : nil
    )

    publish_paid(installment, account_id) if paid_off

    remaining - payment
  end

  def publish_paid(installment, account_id)
    EventPublisher.publish(
      "installment.paid",
      {
        installmentId: installment.id,
        ccbId:         installment.ccb_id,
        accountId:     account_id,
        number:        installment.number,
        amountCents:   installment.amount_cents,
        paidAt:        installment.paid_at&.iso8601
      },
      correlation_id: SecureRandom.uuid
    )
  end
end
