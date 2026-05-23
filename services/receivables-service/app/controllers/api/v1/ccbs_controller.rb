# frozen_string_literal: true

module Api
  module V1
    class CcbsController < BaseController
      def index
        ccbs = Ccb.all
        ccbs = ccbs.where(account_id: params[:account_id]) if params[:account_id].present?
        ccbs = ccbs.order(issued_at: :desc)

        render json: CcbSerializer.new(ccbs).serializable_hash
      end

      def show
        ccb = Ccb.includes(:installments).find(params[:id])
        render json: CcbSerializer.new(ccb, include: [:installments]).serializable_hash
      rescue ActiveRecord::RecordNotFound
        render json: { error: "CCB not found" }, status: :not_found
      end

      def create
        result = IssueCcbService.new.call(
          account_id:        params.dig(:ccb, :account_id),
          principal_cents:   params.dig(:ccb, :principal_cents).to_i,
          discount_cents:    params.dig(:ccb, :discount_cents).to_i,
          annual_rate:       params.dig(:ccb, :annual_rate),
          installment_count: params.dig(:ccb, :installment_count).to_i,
          first_due_date:    params.dig(:ccb, :first_due_date)
        )

        if result.success?
          ccb = result.value!
          render json: CcbSerializer.new(ccb, include: [:installments]).serializable_hash,
                 status: :created
        else
          render_errors(result.failure)
        end
      end
    end
  end
end
