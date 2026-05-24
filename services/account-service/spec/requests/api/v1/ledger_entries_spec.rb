# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LedgerEntries", type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:account) { create(:account) }

  describe "GET /api/v1/accounts/:account_id/ledger_entries" do
    it "returns 401 without auth" do
      get "/api/v1/accounts/#{account.id}/ledger_entries"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns empty data and meta for account with no entries" do
      get "/api/v1/accounts/#{account.id}/ledger_entries", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"]).to eq([])
      meta = json_body["meta"]
      expect(meta["total_count"]).to eq(0)
      expect(meta["total_pages"]).to eq(0)
      expect(meta["current_page"]).to eq(1)
    end

    it "returns entries for the account ordered by created_at desc" do
      create(:ledger_entry, :credit_received, account: account, amount_cents: 100_000,
             idempotency_key: "credit-1")
      create(:ledger_entry, :debit_executed, account: account, amount_cents: 30_000,
             idempotency_key: "debit-1")

      get "/api/v1/accounts/#{account.id}/ledger_entries", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(2)
      expect(json_body["meta"]["total_count"]).to eq(2)
    end

    it "does not return entries from other accounts" do
      other_account = create(:account)
      create(:ledger_entry, :credit_received, account: other_account, idempotency_key: "other-1")
      create(:ledger_entry, :credit_received, account: account, amount_cents: 50_000,
             idempotency_key: "mine-1")

      get "/api/v1/accounts/#{account.id}/ledger_entries", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(1)
    end

    it "paginates results with correct meta" do
      25.times do |i|
        create(:ledger_entry, :credit_received, account: account,
               amount_cents: 1_000, idempotency_key: "key-#{i}")
      end

      get "/api/v1/accounts/#{account.id}/ledger_entries", params: { page: 1, per_page: 10 },
          headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(10)
      meta = json_body["meta"]
      expect(meta["total_count"]).to eq(25)
      expect(meta["total_pages"]).to eq(3)
      expect(meta["current_page"]).to eq(1)
      expect(meta["per_page"]).to eq(10)
    end

    it "returns second page of results" do
      12.times do |i|
        create(:ledger_entry, :credit_received, account: account,
               amount_cents: 1_000, idempotency_key: "key-#{i}")
      end

      get "/api/v1/accounts/#{account.id}/ledger_entries", params: { page: 2, per_page: 10 },
          headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body["data"].length).to eq(2)
      expect(json_body["meta"]["current_page"]).to eq(2)
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
