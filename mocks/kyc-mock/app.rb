# frozen_string_literal: true

require "sinatra"
require "sinatra/json"
require "json"

set :port, 4002
set :bind, "0.0.0.0"

CPF_FORMAT  = /\A\d{3}\.\d{3}\.\d{3}-\d{2}\z/
CNPJ_FORMAT = /\A\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}\z/

before do
  content_type :json
  request.body.rewind
  @body = JSON.parse(request.body.read) rescue {}
end

post "/validate" do
  document = @body["document"].to_s.strip
  valid    = document.match?(CPF_FORMAT) || document.match?(CNPJ_FORMAT)

  result = { document: document, status: valid ? "approved" : "rejected" }
  result[:reason] = "invalid_document_format" unless valid

  json result
end

get "/health" do
  json status: "ok"
end
