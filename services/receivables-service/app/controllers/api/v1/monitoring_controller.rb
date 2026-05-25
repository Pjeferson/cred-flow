# frozen_string_literal: true

require "base64"

module Api
  module V1
    class MonitoringController < BaseController
      def index
        render json: {
          reconciliation: reconciliation_data,
          overdue: overdue_data,
          dlq: dlq_data
        }
      end

      private

      def reconciliation_data
        runs = ReconciliationRun.order(ran_at: :desc).limit(20)
        {
          total_runs: ReconciliationRun.count,
          completed: ReconciliationRun.completed.count,
          with_divergences: ReconciliationRun.with_divergences.count,
          runs: runs.map { |r| serialize_run(r) }
        }
      end

      def overdue_data
        overdue = Installment.overdue
        {
          count: overdue.count,
          total_amount_cents: overdue.sum("amount_cents - paid_cents").to_i,
          oldest_due_date: overdue.minimum(:due_date)
        }
      end

      def dlq_data
        mgmt_url = ENV.fetch("RABBITMQ_MANAGEMENT_URL", "http://rabbitmq:15672")
        user     = ENV.fetch("RABBITMQ_MANAGEMENT_USER", "credflow")
        pass     = ENV.fetch("RABBITMQ_MANAGEMENT_PASS", "credflow")

        conn = Faraday.new(url: mgmt_url) do |f|
          f.headers["Authorization"] = "Basic #{Base64.strict_encode64("#{user}:#{pass}")}"
        end

        resp = conn.get("/api/queues/%2F/q.dead-letter")

        if resp.success?
          data = JSON.parse(resp.body)
          {
            messages:       data["messages"] || 0,
            messages_ready: data["messages_ready"] || 0,
            consumers:      data["consumers"] || 0,
            error:          nil
          }
        elsif resp.status == 404
          # Fila ainda não foi criada (nenhum consumer rodou ou nenhuma mensagem dead-lettered)
          { messages: 0, messages_ready: 0, consumers: 0, error: nil }
        else
          { messages: 0, messages_ready: 0, consumers: 0, error: "management_api_error" }
        end
      rescue Faraday::Error, JSON::ParserError => e
        { messages: 0, messages_ready: 0, consumers: 0, error: e.message }
      end

      def serialize_run(run)
        duration_s = run.finished_at && run.ran_at ? (run.finished_at - run.ran_at).round : nil
        {
          id:                run.id,
          account_id:        run.account_id,
          reference_date:    run.reference_date,
          status:            run.status,
          entries_checked:   run.entries_checked,
          divergences_found: run.divergences_found,
          ran_at:            run.ran_at,
          finished_at:       run.finished_at,
          duration_s:        duration_s,
          error_message:     run.error_message
        }
      end
    end
  end
end
