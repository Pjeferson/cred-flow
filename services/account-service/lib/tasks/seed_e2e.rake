# frozen_string_literal: true

namespace :db do
  desc "Trunca e semeia dados mínimos e controlados para testes E2E (apenas RAILS_ENV=test)"
  task seed_e2e: :environment do
    raise "db:seed:e2e só pode rodar em RAILS_ENV=test" unless Rails.env.test?

    puts "== E2E seed: account-service =="

    ActiveRecord::Base.transaction do
      LedgerEntry.delete_all
      Account.delete_all
      Participant.delete_all
      JwtDenylist.delete_all
      User.delete_all

      User.create!(
        email: "demo@credflow.com",
        name:  "Demo User",
        password: "password123",
        password_confirmation: "password123"
      )

      cedente = Participant.create!(
        id:         "aa000000-0000-0000-0000-000000000001",
        name:       "Cedente E2E Ltda",
        document:   "12.345.678/0001-90",
        role:       "cedente",
        kyc_status: "approved"
      )

      credor1 = Participant.create!(
        id:         "cc000000-0000-0000-0000-000000000001",
        name:       "FIDC Credor Alpha",
        document:   "45.678.901/0001-23",
        role:       "credor",
        kyc_status: "approved"
      )

      Participant.create!(
        id:         "cc000000-0000-0000-0000-000000000002",
        name:       "FIDC Credor Beta",
        document:   "56.789.012/0001-32",
        role:       "credor",
        kyc_status: "approved"
      )

      sacado = Participant.create!(
        id:         "bb000000-0000-0000-0000-000000000001",
        name:       "Sacado E2E S.A.",
        document:   "67.890.123/0001-41",
        role:       "sacado",
        kyc_status: "approved"
      )

      account = Account.create!(
        id:           "11111111-2222-3333-4444-100000000001",
        cedente:      cedente,
        credor:       credor1,
        sacado:       sacado,
        type:         "escrow",
        policy_rules: {
          approval_required_above_cents:     100_000,
          required_approvers:                2,
          new_beneficiary_requires_approval: false
        }
      )

      LedgerEntry.create!(
        account:         account,
        type:            "CREDIT_RECEIVED",
        direction:       "CREDIT",
        amount_cents:    2_000_000,
        status:          "SETTLED",
        idempotency_key: "e2e-credit-001",
        description:     "Crédito inicial E2E"
      )
    end

    puts "   Users: #{User.count} | Participants: #{Participant.count}"
    puts "   Accounts: #{Account.count} | LedgerEntries: #{LedgerEntry.count}"
    puts "== Concluído =="
  end
end
