# frozen_string_literal: true

class CreatePaymentOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_orders, id: :uuid do |t|
      t.uuid    :account_id,         null: false
      t.uuid    :requested_by,       null: false
      t.bigint  :amount_cents,       null: false
      t.string  :beneficiary_doc,    null: false
      t.string  :beneficiary_name
      t.string  :status,             null: false, default: "draft"
      t.string  :policy_action
      t.string  :rejection_reason
      t.string  :spb_transaction_id
      t.string  :idempotency_key,    null: false
      t.datetime :scheduled_for
      t.datetime :expires_at
      t.datetime :executed_at
      t.datetime :settled_at

      t.timestamps
    end

    add_index :payment_orders, :idempotency_key, unique: true
    add_index :payment_orders, %i[account_id status], name: "idx_orders_account_status"
    add_index :payment_orders, :expires_at,
      where: "status = 'pending_approval'",
      name: "idx_orders_expires"
  end
end
