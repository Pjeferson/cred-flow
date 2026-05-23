# frozen_string_literal: true

class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants, id: :uuid do |t|
      t.string :role,           null: false
      t.string :document,       null: false  # CPF (XXX.XXX.XXX-XX) ou CNPJ (XX.XXX.XXX/XXXX-XX)
      t.string :name,           null: false
      t.string :kyc_status,     null: false, default: "pending"
      t.datetime :kyc_checked_at

      t.timestamps
    end

    add_index :participants, :document,  unique: true
    add_index :participants, :kyc_status
  end
end
