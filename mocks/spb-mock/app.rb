# frozen_string_literal: true

require "sinatra"
require "sinatra/json"
require "json"
require "securerandom"

set :port, 4001
set :bind, "0.0.0.0"

# Armazena transações liquidadas em memória: { "account_id:date" => [...] }
SETTLED_TRANSACTIONS = Hash.new { |h, k| h[k] = [] }
MUTEX = Mutex.new

before do
  content_type :json
  request.body.rewind
  @body = JSON.parse(request.body.read) rescue {}
end

# Simula liquidação TED/Pix no SPB. Persiste a transação para o /statement.
post "/settle" do
  if rand < 0.05
    status 422
    json status: "failed", reason: "spb_timeout"
  else
    spb_id = "SPB-#{Time.now.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
    date   = Time.now.strftime("%Y-%m-%d")

    # 2% de chance de registrar valor divergente no SPB (simula erro de centavos)
    stored_amount = rand < 0.02 ? @body["amount_cents"].to_i + rand(-200..200) : @body["amount_cents"].to_i

    tx = {
      spb_transaction_id: spb_id,
      payment_order_id:   @body["payment_order_id"],
      amount_cents:       stored_amount,
      settled_at:         Time.now.iso8601,
      status:             "settled"
    }

    key = "#{@body['account_id']}:#{date}"
    MUTEX.synchronize { SETTLED_TRANSACTIONS[key] << tx }

    json status: "settled", spb_transaction_id: spb_id
  end
end

# GET /statement?account_id=&date=YYYY-MM-DD
# Retorna as transações efetivamente liquidadas via POST /settle para essa conta/data.
get "/statement" do
  account_id = params["account_id"].to_s
  date       = params["date"].to_s

  halt 422, json(error: "account_id and date are required") if account_id.empty? || date.empty?

  key          = "#{account_id}:#{date}"
  transactions = MUTEX.synchronize { SETTLED_TRANSACTIONS[key].dup }

  json transactions: transactions
end

get "/health" do
  json status: "ok"
end
