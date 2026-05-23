# frozen_string_literal: true

require "sinatra"
require "sinatra/json"
require "json"
require "securerandom"

set :port, 4001
set :bind, "0.0.0.0"

before do
  content_type :json
  request.body.rewind
  @body = JSON.parse(request.body.read) rescue {}
end

# Simula liquidação TED/Pix no SPB
post "/settle" do
  # 5% de probabilidade de falha para simular ambiente real
  if rand < 0.05
    status 422
    json status: "failed", reason: "spb_timeout"
  else
    json(
      status: "settled",
      spb_transaction_id: "SPB-#{Time.now.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
    )
  end
end

# GET /statement?account_id=&date=YYYY-MM-DD
# Retorna transações liquidadas para a conta na data. Simula 3% de divergência
# de valor para exercitar o fluxo de reconciliação.
get "/statement" do
  account_id = params["account_id"].to_s
  date       = params["date"].to_s

  halt 422, json(error: "account_id and date are required") if account_id.empty? || date.empty?

  # Gera seed determinístico por conta + data para respostas consistentes
  seed = (account_id + date).bytes.sum
  rng  = Random.new(seed)

  # Simula entre 0 e 3 transações liquidadas naquele dia
  count = rng.rand(0..3)

  transactions = count.times.map do |i|
    base_amount = rng.rand(100_000..5_000_000)
    # 3% de chance de divergência de valor (simula erro de centavos no SPB)
    amount = rng.rand < 0.03 ? base_amount + rng.rand(-500..500) : base_amount

    {
      spb_transaction_id: "SPB-#{date.gsub('-', '')}-#{rng.rand(0xFFFF).to_s(16).upcase.rjust(4, '0')}#{i}",
      amount_cents:       amount,
      settled_at:         "#{date}T#{rng.rand(8..17).to_s.rjust(2, '0')}:00:00Z",
      status:             "settled"
    }
  end

  json transactions: transactions
end

get "/health" do
  json status: "ok"
end
