# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Monitoring", type: :request do
  let(:headers) { auth_headers }

  # Isola a chamada ao RabbitMQ management API
  let(:faraday_conn) { instance_double(Faraday::Connection) }
  let(:dlq_response) do
    instance_double(Faraday::Response,
                    success?: true,
                    body:     '{"messages":0,"messages_ready":0,"consumers":0}')
  end

  before do
    allow(Faraday).to receive(:new).and_return(faraday_conn)
    allow(faraday_conn).to receive(:headers).and_return({})
    allow(faraday_conn).to receive(:get).and_return(dlq_response)
  end

  describe "GET /api/v1/monitoring" do
    it "returns 401 without auth" do
      get "/api/v1/monitoring"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the three monitoring sections" do
      get "/api/v1/monitoring", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body.keys).to match_array(%w[reconciliation overdue dlq])
    end

    context "reconciliation data" do
      it "returns empty runs list when no reconciliation runs exist" do
        get "/api/v1/monitoring", headers: headers
        rec = json_body["reconciliation"]
        expect(rec["total_runs"]).to eq(0)
        expect(rec["runs"]).to eq([])
      end

      it "counts completed runs and those with divergences" do
        create(:reconciliation_run, status: "completed", divergences_found: 0)
        create(:reconciliation_run, :with_divergences)
        create(:reconciliation_run, :failed)

        get "/api/v1/monitoring", headers: headers
        rec = json_body["reconciliation"]
        expect(rec["total_runs"]).to eq(3)
        expect(rec["completed"]).to eq(2)
        expect(rec["with_divergences"]).to eq(1)
      end

      it "returns at most 20 runs ordered by ran_at desc" do
        22.times { |i| create(:reconciliation_run, reference_date: Date.current - i.days) }
        get "/api/v1/monitoring", headers: headers
        expect(json_body["reconciliation"]["runs"].length).to eq(20)
      end

      it "includes run detail attributes" do
        run = create(:reconciliation_run, entries_checked: 15, divergences_found: 2)
        get "/api/v1/monitoring", headers: headers
        run_data = json_body["reconciliation"]["runs"].first
        expect(run_data["id"]).to eq(run.id)
        expect(run_data["entries_checked"]).to eq(15)
        expect(run_data["divergences_found"]).to eq(2)
        expect(run_data["status"]).to eq("completed")
      end
    end

    context "overdue installment data" do
      it "returns zero count when no overdue installments exist" do
        get "/api/v1/monitoring", headers: headers
        expect(json_body["overdue"]["count"]).to eq(0)
        expect(json_body["overdue"]["total_amount_cents"]).to eq(0)
      end

      it "reflects the count and total of overdue installments" do
        ccb = create(:ccb)
        create(:installment, :overdue, ccb: ccb, amount_cents: 50_000, number: 1)
        create(:installment, :overdue, ccb: ccb, amount_cents: 50_000, number: 2)
        create(:installment, ccb: ccb, number: 3)  # pending, should not count

        get "/api/v1/monitoring", headers: headers
        ov = json_body["overdue"]
        expect(ov["count"]).to eq(2)
        expect(ov["total_amount_cents"]).to eq(100_000)
      end

      it "accounts for partial payments in total_amount_cents" do
        ccb = create(:ccb)
        create(:installment, :overdue, ccb: ccb,
               amount_cents: 60_000, paid_cents: 20_000, number: 1)

        get "/api/v1/monitoring", headers: headers
        expect(json_body["overdue"]["total_amount_cents"]).to eq(40_000)
      end
    end

    context "DLQ data" do
      it "returns DLQ message count from management API" do
        get "/api/v1/monitoring", headers: headers
        dlq = json_body["dlq"]
        expect(dlq["messages"]).to eq(0)
        expect(dlq["error"]).to be_nil
      end

      it "returns error key when management API is unavailable" do
        allow(faraday_conn).to receive(:get).and_raise(Faraday::ConnectionFailed.new("refused"))

        get "/api/v1/monitoring", headers: headers
        dlq = json_body["dlq"]
        expect(dlq["error"]).not_to be_nil
        expect(dlq["messages"]).to eq(0)
      end
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
