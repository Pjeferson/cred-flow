# frozen_string_literal: true

class IssueCcbService
  include Dry::Monads[:result]

  def call(account_id:, principal_cents:, discount_cents: 0, annual_rate:,
           installment_count:, first_due_date:)

    ccb = nil

    ActiveRecord::Base.transaction do
      ccb = Ccb.create!(
        account_id:        account_id,
        principal_cents:   principal_cents,
        discount_cents:    discount_cents,
        annual_rate:       annual_rate,
        installment_count: installment_count,
        first_due_date:    first_due_date
      )

      result = InstallmentScheduler.new.call(ccb)
      raise ActiveRecord::Rollback, result.failure unless result.success?
    end

    return Failure("ccb_not_created") unless ccb&.persisted?

    Success(ccb.reload)
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end
end
