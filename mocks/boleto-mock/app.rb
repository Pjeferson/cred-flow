# frozen_string_literal: true

require "sinatra"
require "sinatra/json"
require "json"
require "date"
require "securerandom"

set :port, 4003
set :bind, "0.0.0.0"
set :host_authorization, { permitted_hosts: [] }

# Base date for boleto due-date factor (days since 07/10/1997)
BOLETO_BASE_DATE = Date.new(1997, 10, 7)

# Bank code used in the mock (341 = Itaú, widely recognized)
BANK_CODE = "341"
CURRENCY  = "9"

before do
  content_type :json
  request.body.rewind
  @body = JSON.parse(request.body.read) rescue {}
end

# POST /boleto
# Params: installment_id, ccb_id, amount_cents, due_date (ISO8601 date), sacado_doc
# Returns: barcode, linha_digitavel, boleto_id
post "/boleto" do
  amount_cents  = @body["amount_cents"].to_i
  due_date_str  = @body["due_date"].to_s
  installment_id = @body["installment_id"].to_s

  halt 422, json(error: "amount_cents must be positive") unless amount_cents > 0
  halt 422, json(error: "due_date is required")          if due_date_str.empty?

  due_date    = Date.parse(due_date_str)
  due_factor  = (due_date - BOLETO_BASE_DATE).to_i.clamp(1000, 9999).to_s.rjust(4, "0")
  value_str   = amount_cents.to_s.rjust(10, "0")

  # 25-digit free field: installment_id (truncated/padded) encoded as digits
  free_field = installment_id.gsub(/[^0-9]/, "").ljust(25, "0")[0, 25]
  free_field = free_field.rjust(25, "0")

  # Barcode (44 digits, without check digit at position 5):
  # [bank 3][currency 1][due_factor 4][value 10][free_field 25]
  barcode_without_check = "#{BANK_CODE}#{CURRENCY}#{due_factor}#{value_str}#{free_field}"

  check = mod11_check(barcode_without_check.chars.map(&:to_i))

  # Full barcode: bank(3) + currency(1) + check(1) + due_factor(4) + value(10) + free(25)
  barcode = "#{BANK_CODE}#{CURRENCY}#{check}#{due_factor}#{value_str}#{free_field}"

  linha_digitavel = build_linha_digitavel(barcode)

  json(
    boleto_id:       "BOL-#{SecureRandom.hex(6).upcase}",
    barcode:         barcode,
    linha_digitavel: linha_digitavel,
    amount_cents:    amount_cents,
    due_date:        due_date_str
  )
end

get "/health" do
  json status: "ok"
end

private

# Modulo 10 — used for the check digit of each linha digitável field
def mod10_check(digits)
  sum = 0
  digits.reverse.each_with_index do |d, i|
    n = d * (i.even? ? 2 : 1)
    sum += n >= 10 ? n - 9 : n
  end
  (10 - (sum % 10)) % 10
end

# Modulo 11 — used for the overall barcode check digit (position 5)
def mod11_check(digits)
  weights = [2, 3, 4, 5, 6, 7, 8, 9].cycle
  total   = digits.reverse.sum { |d| d * weights.next }
  rem     = total % 11
  (rem == 0 || rem == 1) ? 1 : 11 - rem
end

# Builds the human-readable linha digitável from the 44-digit barcode.
#
# Barcode layout:  [bank 3][currency 1][check 1][due 4][value 10][free 25]
#  positions:       1-3      4          5        6-9    10-19     20-44
#
# Linha digitável layout (47 digits printed as "AAAAA.AAAAA BBBBB.BBBBBB CCCCC.CCCCCC D EEEEEEEEEEEEEE"):
#  Field 1 (10): bank(3) + currency(1) + free[1..5]  + mod10
#  Field 2 (11): free[6..15]                          + mod10
#  Field 3 (11): free[16..25]                         + mod10
#  Field 4  (1): check digit (position 5 of barcode)
#  Field 5 (14): due_factor(4) + value(10)
def build_linha_digitavel(barcode)
  bank     = barcode[0, 3]
  currency = barcode[3]
  check    = barcode[4]
  due      = barcode[5, 4]
  value    = barcode[9, 10]
  free     = barcode[19, 25]

  f1_digits = (bank + currency + free[0, 5]).chars.map(&:to_i)
  f1 = (bank + currency + free[0, 5]).dup
  f1 << mod10_check(f1_digits).to_s

  f2_digits = free[5, 10].chars.map(&:to_i)
  f2 = free[5, 10].dup
  f2 << mod10_check(f2_digits).to_s

  f3_digits = free[15, 10].chars.map(&:to_i)
  f3 = free[15, 10].dup
  f3 << mod10_check(f3_digits).to_s

  "#{f1[0, 5]}.#{f1[5..]} #{f2[0, 5]}.#{f2[5..]} #{f3[0, 5]}.#{f3[5..]} #{check} #{due}#{value}"
end
