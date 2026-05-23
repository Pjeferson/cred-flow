# frozen_string_literal: true

class CreateApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :approvals, id: :uuid do |t|
      t.references :payment_order, null: false, foreign_key: true, type: :uuid
      t.uuid    :approver_id, null: false
      t.string  :decision,    null: false
      t.inet    :ip_address
      t.text    :user_agent
      t.datetime :decided_at, null: false, default: -> { "NOW()" }
    end

    add_index :approvals, %i[payment_order_id approver_id],
      unique: true,
      name: "uq_approval_per_approver"

    add_index :approvals, %i[payment_order_id decision],
      name: "idx_approvals_order"
  end
end
