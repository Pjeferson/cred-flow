# frozen_string_literal: true

module Api
  module V1
    class LedgerEntriesController < BaseController
      PER_PAGE = 20

      def index
        page     = [params.fetch(:page, 1).to_i, 1].max
        per_page = [params.fetch(:per_page, PER_PAGE).to_i, 100].min

        entries = LedgerEntry
          .where(account_id: params[:account_id])
          .order(created_at: :desc)
          .limit(per_page)
          .offset((page - 1) * per_page)

        total = LedgerEntry.where(account_id: params[:account_id]).count

        render json: LedgerEntrySerializer.new(entries).serializable_hash.merge(
          meta: {
            total_count:  total,
            total_pages:  (total.to_f / per_page).ceil,
            current_page: page,
            per_page:     per_page
          }
        )
      end
    end
  end
end
