# frozen_string_literal: true

module Internal
  class LedgerEntriesController < BaseController
    def index
      entries = LedgerEntry.where(account_id: params[:account_id])
      entries = entries.where(type: params[:type])             if params[:type].present?
      entries = entries.where(status: params[:status])         if params[:status].present?
      entries = entries.where("created_at::date = ?", params[:date]) if params[:date].present?
      entries = entries.order(created_at: :asc)

      render json: entries.map { |e|
        { id: e.id, type: e.type, amount_cents: e.amount_cents,
          status: e.status, payment_order_id: e.payment_order_id,
          idempotency_key: e.idempotency_key, created_at: e.created_at.iso8601 }
      }
    end

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
