# frozen_string_literal: true

class CreateCcbs < ActiveRecord::Migration[8.1]
  def change
    create_table :ccbs, id: :uuid do |t|
      t.uuid    :account_id,        null: false
      t.bigint  :principal_cents,   null: false
      t.bigint  :discount_cents,    null: false, default: 0
      t.bigint  :net_cents,         null: false
      t.decimal :annual_rate,       null: false, precision: 5, scale: 4
      t.integer :installment_count, null: false
      t.date    :first_due_date,    null: false
      t.string  :status,            null: false, default: "active"
      t.datetime :issued_at,        null: false, default: -> { "NOW()" }
      t.datetime :settled_at

      t.index %i[account_id status], name: "idx_ccbs_account"
    end

    add_check_constraint :ccbs, "principal_cents > 0",      name: "chk_ccbs_principal_positive"
    add_check_constraint :ccbs, "installment_count > 0",    name: "chk_ccbs_installment_count"
    add_check_constraint :ccbs, "status IN ('active', 'settled', 'defaulted', 'cancelled')", name: "chk_ccbs_status"
  end
end
