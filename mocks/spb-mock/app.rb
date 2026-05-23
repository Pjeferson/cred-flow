# frozen_string_literal: true

require "sinatra"
require "sinatra/json"
require "json"
require "securerandom"
require "sqlite3"

set :port, 4001
set :bind, "0.0.0.0"

DB = SQLite3::Database.new(ENV.fetch("DB_PATH", "./db/spb.sqlite3")).tap do |conn|
  conn.results_as_hash = true
  conn.execute(File.read("./db/schema.sql"))
end

before do
  content_type :json
  request.body.rewind
  @body = JSON.parse(request.body.read) rescue {}
end

# Simula liquidação TED/Pix no SPB. Persiste a transação no SQLite.
post "/settle" do
  if rand < 0.05
    status 422
    json status: "failed", reason: "spb_timeout"
  else
    spb_id = "SPB-#{Time.now.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"

    # 2% de chance de registrar valor divergente no SPB (simula erro de centavos)
    stored_amount = rand < 0.02 ? @body["amount_cents"].to_i + rand(-200..200) : @body["amount_cents"].to_i

    DB.execute(
      "INSERT INTO spb_transactions (spb_transaction_id, account_id, payment_order_id, amount_cents, settled_at) VALUES (?, ?, ?, ?, ?)",
      [spb_id, @body["account_id"].to_s, @body["payment_order_id"].to_s, stored_amount, Time.now.iso8601]
    )

    json status: "settled", spb_transaction_id: spb_id
  end
end

# GET /statement?account_id=&date=YYYY-MM-DD
# Retorna as transações efetivamente liquidadas via POST /settle para essa conta/data.
get "/statement" do
  account_id = params["account_id"].to_s
  date       = params["date"].to_s

  halt 422, json(error: "account_id and date are required") if account_id.empty? || date.empty?

  transactions = DB.execute(
    "SELECT spb_transaction_id, account_id, payment_order_id, amount_cents, settled_at, status FROM spb_transactions WHERE account_id = ? AND date(settled_at) = ?",
    [account_id, date]
  ).map { |row| row.transform_keys(&:to_sym) }

  json transactions: transactions
end

get "/health" do
  json status: "ok"
end
