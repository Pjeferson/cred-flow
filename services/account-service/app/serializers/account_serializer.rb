# frozen_string_literal: true

class AccountSerializer
  include JSONAPI::Serializer

  set_type :account

  attributes :type, :status, :policy_rules, :created_at
  attribute  :cedente_id
  attribute  :credor_id
  attribute  :sacado_id
end
