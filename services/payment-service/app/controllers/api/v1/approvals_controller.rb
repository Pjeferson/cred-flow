# frozen_string_literal: true

module Api
  module V1
    class ApprovalsController < BaseController
      def create
        order = PaymentOrder.find(params[:payment_order_id])

        result = ProcessApprovalService.new.call(
          payment_order: order,
          approver_id:   params.dig(:approval, :approver_id),
          decision:      params.dig(:approval, :decision)&.upcase,
          ip_address:    request.remote_ip,
          user_agent:    request.user_agent
        )

        if result.success?
          data = result.value!
          render json: {
            order:    PaymentOrderSerializer.new(data[:order]).serializable_hash,
            approval: ApprovalSerializer.new(data[:approval]).serializable_hash
          }, status: :created
        else
          render_errors(result.failure)
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "PaymentOrder not found" }, status: :not_found
      end
    end
  end
end
