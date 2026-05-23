# frozen_string_literal: true

class OpenAccountService
  include Dry::Monads[:result]

  def call(type:, cedente_id:, credor_id:, policy_rules: {}, sacado_id: nil)
    account = Account.new(
      type:         type,
      cedente_id:   cedente_id,
      credor_id:    credor_id,
      sacado_id:    sacado_id,
      policy_rules: policy_rules
    )

    if account.save
      Success(account)
    else
      Failure(account.errors.full_messages)
    end
  rescue ActiveRecord::RecordNotFound => e
    Failure(["participant_not_found: #{e.message}"])
  end
end
