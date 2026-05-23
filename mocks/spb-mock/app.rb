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

get "/health" do
  json status: "ok"
end
