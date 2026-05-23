# frozen_string_literal: true

class CreateJwtDenylists < ActiveRecord::Migration[8.1]
  def change
    create_table :jwt_denylists, id: :uuid do |t|
      t.string   :jti, null: false
      t.datetime :exp, null: false
    end

    add_index :jwt_denylists, :jti, unique: true
  end
end
