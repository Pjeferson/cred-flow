# frozen_string_literal: true

module Api
  module V1
    class AccountsController < BaseController
      def index
        accounts = Account.includes(:cedente, :credor, :sacado)
                          .order(created_at: :desc)
        render json: AccountSerializer.new(accounts).serializable_hash
      end

      def show
        render json: AccountSerializer.new(
          Account.includes(:cedente, :credor, :sacado).find(params[:id])
        ).serializable_hash
      end

      def create
        result = OpenAccountService.new.call(**open_account_params)

        if result.success?
          render json: AccountSerializer.new(result.value!).serializable_hash,
                 status: :created
        else
          render_errors(result.failure)
        end
      end

      def balance
        calculator = BalanceCalculator.call(account_id: account.id)
        render json: {
          account_id:      account.id,
          balance_cents:   calculator.balance_cents,
          available_cents: calculator.available_cents
        }
      end

      private

      def account
        @account ||= Account.find(params[:id])
      end

      def open_account_params
        base   = params.require(:account).permit(:type, :cedente_id, :credor_id, :sacado_id)
        policy = params.dig(:account, :policy_rules)&.to_unsafe_h || {}

        base.to_h.symbolize_keys.merge(policy_rules: policy)
      end
    end
  end
end
