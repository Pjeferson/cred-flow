# frozen_string_literal: true

class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid do |t|
      t.string :type,       null: false  # escrow | empresa
      t.uuid   :cedente_id, null: false
      t.uuid   :credor_id,  null: false
      t.uuid   :sacado_id                # nullable em conta empresa
      t.string :status,     null: false, default: "active"
      t.jsonb  :policy_rules, null: false, default: {}

      t.timestamps
    end

    add_index :accounts, :cedente_id
    add_index :accounts, :credor_id
    add_index :accounts, :status

    add_foreign_key :accounts, :participants, column: :cedente_id
    add_foreign_key :accounts, :participants, column: :credor_id
  end
end
