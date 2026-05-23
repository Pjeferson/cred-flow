# frozen_string_literal: true

class CreateInstallments < ActiveRecord::Migration[8.1]
  def change
    create_table :installments, id: :uuid do |t|
      t.references :ccb, null: false, foreign_key: true, type: :uuid
      t.integer :number,       null: false
      t.bigint  :amount_cents, null: false
      t.bigint  :paid_cents,   null: false, default: 0
      t.date    :due_date,     null: false
      t.date    :paid_at
      t.string  :status,       null: false, default: "pending"
      t.timestamps null: false

      t.index %i[ccb_id status], name: "idx_installments_ccb"
      t.index :due_date,
              name: "idx_installments_due",
              where: "status IN ('pending', 'partially_paid')"
    end

    add_check_constraint :installments,
                         "status IN ('pending', 'partially_paid', 'paid', 'overdue')",
                         name: "chk_installments_status"

    add_index :installments, %i[ccb_id number], unique: true, name: "uq_installment_number"
  end
end
