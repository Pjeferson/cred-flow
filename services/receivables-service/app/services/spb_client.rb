# frozen_string_literal: true

class SpbClient
  include Dry::Monads[:result]

  BASE_URL = ENV.fetch("SPB_MOCK_URL", "http://spb-mock:4001")

  def fetch_statement(account_id:, date:)
    conn = Faraday.new(url: BASE_URL) do |f|
      f.headers["Content-Type"] = "application/json"
      f.adapter Faraday.default_adapter
    end

    resp = conn.get("/statement", account_id: account_id, date: date)
    resp.success? ? Success(JSON.parse(resp.body, symbolize_names: true)[:transactions] || []) : Failure("spb_error")
  rescue Faraday::Error => e
    Failure("spb_unavailable: #{e.message}")
  end
end
