# frozen_string_literal: true

class AccountServiceClient
  include Dry::Monads[:result]

  def fetch_account(account_id)
    response = connection.get("/internal/accounts/#{account_id}")

    return Failure("account_not_found")           if response.status == 404
    return Failure("account_service_unavailable") unless response.success?

    Success(JSON.parse(response.body, symbolize_names: true))
  rescue Faraday::Error => e
    Failure("account_service_error: #{e.message}")
  end

  def create_ledger_entry(account_id:, type:, amount_cents:, payment_order_id:, idempotency_key:, status: "SETTLED")
    response = connection.post(
      "/internal/accounts/#{account_id}/ledger_entries",
      { type:, amount_cents:, payment_order_id:, idempotency_key:, status: }.to_json
    )

    return Failure("ledger_error: #{response.status}") unless response.success?

    data = JSON.parse(response.body, symbolize_names: true)
    Success(data[:id])
  rescue Faraday::Error => e
    Failure("account_service_error: #{e.message}")
  end

  private

  def connection
    @connection ||= Faraday.new(url: ENV.fetch("ACCOUNT_SERVICE_URL")) do |f|
      f.headers["X-Service-Key"] = ENV.fetch("INTERNAL_SERVICE_KEY", "credflow-internal")
      f.headers["Content-Type"]  = "application/json"
    end
  end
end
