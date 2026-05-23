# frozen_string_literal: true

class ExecutePaymentService
  include Dry::Monads[:result]

  def call(order)
    order.start_execution!

    reserved_key  = "debit_reserved:#{order.id}"
    reserve_result = AccountServiceClient.new.create_ledger_entry(
      account_id:       order.account_id,
      type:             "DEBIT_RESERVED",
      amount_cents:     order.amount_cents,
      payment_order_id: order.id,
      idempotency_key:  reserved_key,
      status:           "PENDING"
    )

    unless reserve_result.success?
      order.fail!
      order.update_columns(rejection_reason: "reservation_failed")
      return Failure("reservation_failed")
    end

    reserved_entry_id = reserve_result.value!

    spb = call_spb(order)

    if spb[:status] == "settled"
      order.update_columns(spb_transaction_id: spb[:spb_transaction_id], executed_at: Time.current)
      order.settle!

      EventPublisher.publish(
        "payment.settled",
        {
          paymentOrderId:   order.id,
          accountId:        order.account_id,
          amountCents:      order.amount_cents,
          beneficiaryDoc:   order.beneficiary_doc,
          settledAt:        Time.current.iso8601,
          spbTransactionId: spb[:spb_transaction_id]
        },
        correlation_id: SecureRandom.uuid
      )
    else
      order.fail!
      order.update_columns(rejection_reason: spb[:reason] || "spb_error")

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

    Success(order.reload)
  rescue AASM::InvalidTransition => e
    Failure("invalid_transition: #{e.message}")
  end

  private

  def call_spb(order)
    conn = Faraday.new(url: ENV.fetch("SPB_MOCK_URL")) do |f|
      f.headers["Content-Type"] = "application/json"
    end
    response = conn.post("/settle", {
      payment_order_id: order.id,
      amount_cents:     order.amount_cents,
      beneficiary_doc:  order.beneficiary_doc
    }.to_json)

    JSON.parse(response.body, symbolize_names: true)
  rescue Faraday::Error
    { status: "failed", reason: "spb_connection_error" }
  end
end
