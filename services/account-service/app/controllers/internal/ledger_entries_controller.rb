# frozen_string_literal: true

module Internal
  class LedgerEntriesController < BaseController
    def create
      result = LedgerWriterService.new.call(
        account_id:       params[:account_id],
        type:             params.require(:type),
        amount_cents:     params.require(:amount_cents).to_i,
        idempotency_key:  params.require(:idempotency_key),
        status:           params.fetch(:status, "SETTLED"),
        payment_order_id: params[:payment_order_id],
        description:      params[:description]
      )

      if result.success?
        render json: { id: result.value!.id }, status: :created
      else
        render json: { error: result.failure }, status: :unprocessable_entity
      end
    end
  end
end
