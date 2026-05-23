# frozen_string_literal: true

module Internal
  class AccountsController < BaseController
    def show
      account = Account.find(params[:id])
      render json: {
        id:           account.id,
        status:       account.status,
        policy_rules: account.policy_rules
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Account not found" }, status: :not_found
    end
  end
end
