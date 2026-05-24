# frozen_string_literal: true

namespace :db do
  desc "Trunca e semeia dados mínimos e controlados para testes E2E (apenas RAILS_ENV=test)"
  task seed_e2e: :environment do
    raise "db:seed:e2e só pode rodar em RAILS_ENV=test" unless Rails.env.test?

    puts "== E2E seed: payment-service =="

    ActiveRecord::Base.transaction do
      Approval.delete_all
      PaymentOrder.delete_all

      # IDs fixos — coincidem com account-service E2E seed
      account_id = "11111111-2222-3333-4444-100000000001"
      requester  = "dd000000-0000-0000-0000-000000000001"

      # Duas ordens pending_approval sem aprovações pré-existentes.
      # required_approvers=2 na conta — uma aprovação do teste não dispara liquidação,
      # só registra a decisão e fecha o modal.
      [
        { key: "e2e-po-001", amount: 250_000, doc: "67.890.123/0001-41", name: "Fornecedor E2E Alpha" },
        { key: "e2e-po-002", amount: 180_000, doc: "78.901.234/0001-50", name: "Fornecedor E2E Beta" }
      ].each do |attrs|
        order = PaymentOrder.create!(
          account_id:       account_id,
          amount_cents:     attrs[:amount],
          beneficiary_doc:  attrs[:doc],
          beneficiary_name: attrs[:name],
          idempotency_key:  attrs[:key],
          policy_action:    "pending_approval",
          requested_by:     requester,
          expires_at:       24.hours.from_now
        )
        order.update_column(:status, "pending_approval")
      end
    end

    puts "   PaymentOrders pending_approval: #{PaymentOrder.where(status: 'pending_approval').count}"
    puts "   Approvals pré-existentes: #{Approval.count} (deve ser 0)"
    puts "== Concluído =="
  end
end
