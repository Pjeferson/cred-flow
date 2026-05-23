# frozen_string_literal: true

class AccountServiceClient
  include Dry::Monads[:result]

  BASE_URL = ENV.fetch("ACCOUNT_SERVICE_URL", "http://account-service:3000")
  HEADERS  = {
    "Content-Type"   => "application/json",
    "X-Service-Key"  => ENV.fetch("INTERNAL_SERVICE_KEY", "credflow-internal")
  }.freeze

  def fetch_ledger_entries(account_id, type: nil, date: nil, status: nil)
    conn   = build_connection
    params = { type: type, date: date, status: status }.compact
    resp   = conn.get("/internal/accounts/#{account_id}/ledger_entries", params)

    resp.success? ? Success(JSON.parse(resp.body, symbolize_names: true)) : Failure("account_service_error")
  rescue Faraday::Error => e
    Failure("account_service_unavailable: #{e.message}")
  end

  private

  def build_connection
    Faraday.new(url: BASE_URL) do |f|
      f.headers.merge!(HEADERS)
      f.adapter Faraday.default_adapter
    end
  end
end
