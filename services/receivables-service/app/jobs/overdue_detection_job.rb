# frozen_string_literal: true

class OverdueDetectionJob < ApplicationJob
  queue_as :default

  def perform
    overdue = Installment
      .joins(:ccb)
      .where(status: %w[pending partially_paid])
      .where("installments.due_date < ?", Date.current)

    overdue.find_each do |installment|
      installment.update!(status: "overdue")

      EventPublisher.publish(
        "installment.overdue",
        {
          installmentId: installment.id,
          ccbId:         installment.ccb_id,
          accountId:     installment.ccb.account_id,
          number:        installment.number,
          amountCents:   installment.amount_cents,
          paidCents:     installment.paid_cents,
          dueDate:       installment.due_date.iso8601,
          daysOverdue:   (Date.current - installment.due_date).to_i
        },
        correlation_id: SecureRandom.uuid
      )
    rescue => e
      Rails.logger.error("[OverdueDetectionJob] Installment #{installment.id}: #{e.message}")
    end
  end
end
