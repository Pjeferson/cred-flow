# frozen_string_literal: true

class InstallmentScheduler
  include Dry::Monads[:result]

  # Gera o cronograma de parcelas em batch na mesma transação da CCB.
  # O último valor absorve o centavo residual para garantir que a soma
  # das parcelas seja exatamente igual ao principal_cents.
  def call(ccb)
    return Failure("ccb_not_persisted") unless ccb.persisted?

    base  = ccb.principal_cents / ccb.installment_count
    extra = ccb.principal_cents % ccb.installment_count

    installments = (1..ccb.installment_count).map do |n|
      amount = n == ccb.installment_count ? base + extra : base
      {
        ccb_id:       ccb.id,
        number:       n,
        amount_cents: amount,
        paid_cents:   0,
        due_date:     ccb.first_due_date >> (n - 1),
        status:       "pending",
        created_at:   Time.current,
        updated_at:   Time.current
      }
    end

    Installment.insert_all!(installments)
    Success(ccb)
  rescue ActiveRecord::RecordNotUnique
    Failure("installments_already_exist")
  rescue ActiveRecord::ActiveRecordError => e
    Failure(e.message)
  end
end
