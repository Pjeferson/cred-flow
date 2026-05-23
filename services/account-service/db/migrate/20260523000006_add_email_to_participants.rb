# frozen_string_literal: true

class AddEmailToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :email, :string

    add_index :participants, :email, unique: true
  end
end
