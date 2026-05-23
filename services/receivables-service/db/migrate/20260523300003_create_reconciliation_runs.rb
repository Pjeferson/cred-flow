# frozen_string_literal: true

class CreateReconciliationRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :reconciliation_runs, id: :uuid do |t|
      t.uuid    :account_id,        null: false
      t.date    :reference_date,    null: false
      t.integer :entries_checked,   null: false, default: 0
      t.integer :divergences_found, null: false, default: 0
      t.string  :status,            null: false, default: "running"
      t.text    :error_message
      t.datetime :ran_at,           null: false, default: -> { "NOW()" }
      t.datetime :finished_at

      t.index %i[account_id reference_date],
              name: "idx_reconciliation_account",
              order: { reference_date: :desc }
    end

    add_check_constraint :reconciliation_runs,
                         "status IN ('running', 'completed', 'failed')",
                         name: "chk_reconciliation_runs_status"

    add_index :reconciliation_runs, %i[account_id reference_date],
              unique: true,
              name: "uq_reconciliation_date"
  end
end
