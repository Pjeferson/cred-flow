# frozen_string_literal: true

class LedgerWriterService
  include Dry::Monads[:result]

  def call(account_id:, type:, amount_cents:, idempotency_key:,
           status: "SETTLED", payment_order_id: nil, description: nil)

    direction = LedgerEntry::DIRECTION_BY_TYPE.fetch(type)

    entry = LedgerEntry.create!(
      account_id:       account_id,
      type:             type,
      direction:        direction,
      amount_cents:     amount_cents,
      status:           status,
      payment_order_id: payment_order_id,
      idempotency_key:  idempotency_key,
      description:      description
    )

    Success(entry)
  rescue ActiveRecord::RecordNotUnique
    # Idempotência: lançamento já existe, retorna o existente
    entry = LedgerEntry.find_by!(account_id: account_id, idempotency_key: idempotency_key)
    Success(entry)
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end
end
