# frozen_string_literal: true

module Api
  module V1
    class PaymentOrdersController < BaseController
      include Idempotent

      def index
        orders = PaymentOrder
          .includes(:approvals)
          .then { params[:account_id].present? ? _1.where(account_id: params[:account_id]) : _1 }
          .then { params[:status].present? ? _1.where(status: params[:status]) : _1 }
          .order(created_at: :desc)
        render json: PaymentOrderSerializer.new(orders).serializable_hash
      end

      def show
        order = payment_order
        return if performed?
        render json: PaymentOrderSerializer.new(order).serializable_hash
      end

      def create
        result = CreatePaymentOrderService.new.call(
          account_id:      params.dig(:payment_order, :account_id),
          requested_by:    params.dig(:payment_order, :requested_by),
          amount_cents:    params.dig(:payment_order, :amount_cents).to_i,
          beneficiary_doc: params.dig(:payment_order, :beneficiary_doc),
          beneficiary_name: params.dig(:payment_order, :beneficiary_name),
          idempotency_key: @idempotency_key
        )

        if result.success?
          body = PaymentOrderSerializer.new(result.value!).serializable_hash
          cache_idempotency_response(body, 201)
          render json: body, status: :created
        else
          render_errors(result.failure)
        end
      end

      private

      def payment_order
        @payment_order ||= PaymentOrder.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end
    end
  end
end
