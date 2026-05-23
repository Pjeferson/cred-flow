# frozen_string_literal: true

class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_entries, id: :uuid do |t|
      t.uuid    :account_id,       null: false
      t.string  :type,             null: false   # CREDIT_ANTECIPATION | CREDIT_RECEIVED | DEBIT_*
      t.string  :direction,        null: false   # CREDIT | DEBIT
      t.bigint  :amount_cents,     null: false
      t.string  :status,           null: false, default: "SETTLED"
      t.uuid    :payment_order_id               # FK lógica para payment-service (sem constraint)
      t.string  :idempotency_key,  null: false
      t.text    :description

      # Sem updated_at — ledger é append-only
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :ledger_entries, %i[account_id idempotency_key], unique: true,
              name: "uq_ledger_idempotency"
    add_index :ledger_entries, %i[account_id status],
              name: "idx_ledger_account_status"
    add_index :ledger_entries, %i[account_id created_at],
              name: "idx_ledger_created", order: { created_at: :desc }

    add_foreign_key :ledger_entries, :accounts, column: :account_id
  end
end
