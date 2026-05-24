# frozen_string_literal: true

class AccountSerializer
  include JSONAPI::Serializer

  set_type :account

  attributes :type, :status, :policy_rules, :created_at
  attribute  :cedente_id
  attribute  :credor_id
  attribute  :sacado_id

  attribute(:cedente_name) { |a| a.cedente&.name }
  attribute(:credor_name)  { |a| a.credor&.name }
  attribute(:sacado_name)  { |a| a.sacado&.name }
end
