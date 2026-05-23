# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  FRONTEND_URL = ENV.fetch("FRONTEND_URL", "http://localhost:5173")

  def approval_requested(payment_order_id:, account_id:, amount_cents:, reason:,
                         approvers_needed:, approvals_received:, expires_at:, beneficiary_doc:,
                         to:)
    @payment_order_id   = payment_order_id
    @account_id         = account_id
    @amount_reais       = format("R$ %.2f", amount_cents.to_f / 100)
    @reason             = reason
    @approvers_needed   = approvers_needed
    @approvals_received = approvals_received
    @expires_at         = expires_at
    @beneficiary_doc    = beneficiary_doc
    @approval_link      = "#{FRONTEND_URL}/payment-orders/#{payment_order_id}/approvals"

    mail(to: to, subject: "[CredFlow] Aprovação necessária — #{@amount_reais}")
  end

  def payment_failed(payment_order_id:, account_id:, amount_cents:, reason:, to:)
    @payment_order_id = payment_order_id
    @account_id       = account_id
    @amount_reais     = format("R$ %.2f", amount_cents.to_f / 100)
    @reason           = reason
    @details_link     = "#{FRONTEND_URL}/payment-orders/#{payment_order_id}"

    mail(to: to, subject: "[CredFlow] Falha no pagamento — #{@amount_reais}")
  end
end
