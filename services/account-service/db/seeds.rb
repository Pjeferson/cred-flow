# frozen_string_literal: true

require "faker"

puts "\n== Seeding account-service =="

# IDs fixos compartilhados com payment-service e receivables-service
ACCOUNT_1_ID = "11111111-2222-3333-4444-100000000001"
ACCOUNT_2_ID = "11111111-2222-3333-4444-100000000002"
ACCOUNT_3_ID = "11111111-2222-3333-4444-100000000003"

# == Users ==
puts "-- Users"
[
  { email: "demo@credflow.com",  name: "Demo User",        password: "password123" },
  { email: "admin@credflow.com", name: "Admin CredFlow",   password: "password123" }
].each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  if user.new_record?
    user.assign_attributes(name: attrs[:name], password: attrs[:password], password_confirmation: attrs[:password])
    user.save!
    puts "   Criado: #{attrs[:email]}"
  else
    puts "   Já existe: #{attrs[:email]}"
  end
end

# == Participants ==
puts "-- Participants"

cedente1 = Participant.find_or_create_by!(document: "12.345.678/0001-90") do |p|
  p.name       = "Agro Norte Exportações S.A."
  p.role       = "cedente"
  p.kyc_status = "approved"
end

cedente2 = Participant.find_or_create_by!(document: "23.456.789/0001-05") do |p|
  p.name       = "Construtora Horizonte Ltda"
  p.role       = "cedente"
  p.kyc_status = "approved"
end

cedente3 = Participant.find_or_create_by!(document: "34.567.890/0001-14") do |p|
  p.name       = "Tech Soluções Digitais ME"
  p.role       = "cedente"
  p.kyc_status = "approved"
end

credor1 = Participant.find_or_create_by!(document: "45.678.901/0001-23") do |p|
  p.name       = "FIDC Capital Nordeste"
  p.role       = "credor"
  p.kyc_status = "approved"
end

credor2 = Participant.find_or_create_by!(document: "56.789.012/0001-32") do |p|
  p.name       = "FIDC Agro Investimentos"
  p.role       = "credor"
  p.kyc_status = "approved"
end

sacado1 = Participant.find_or_create_by!(document: "67.890.123/0001-41") do |p|
  p.name       = "Distribuidora Alfa Ltda"
  p.role       = "sacado"
  p.kyc_status = "approved"
end

sacado2 = Participant.find_or_create_by!(document: "78.901.234/0001-50") do |p|
  p.name       = "Supermercados Beta S.A."
  p.role       = "sacado"
  p.kyc_status = "approved"
end

sacado3 = Participant.find_or_create_by!(document: "89.012.345/0001-69") do |p|
  p.name       = "Atacado Gama Comércio Ltda"
  p.role       = "sacado"
  p.kyc_status = "approved"
end

puts "   #{Participant.count} participantes"

# == Accounts (escrow) ==
puts "-- Accounts"

[
  {
    id:           ACCOUNT_1_ID,
    cedente:      cedente1,
    credor:       credor1,
    sacado:       sacado1,
    policy_rules: {
      approval_required_above_cents:   100_000,
      required_approvers:              2,
      new_beneficiary_requires_approval: true
    }
  },
  {
    id:           ACCOUNT_2_ID,
    cedente:      cedente2,
    credor:       credor1,
    sacado:       sacado2,
    policy_rules: {
      approval_required_above_cents: 200_000,
      required_approvers:            1,
      daily_limit_cents:             1_000_000
    }
  },
  {
    id:           ACCOUNT_3_ID,
    cedente:      cedente3,
    credor:       credor2,
    sacado:       sacado3,
    policy_rules: {
      approval_required_above_cents: 50_000,
      required_approvers:            2,
      blocked_hours:                 { start: "18:00", end: "09:00" }
    }
  }
].each_with_index do |attrs, i|
  if Account.exists?(id: attrs[:id])
    puts "   Conta #{i + 1} já existe"
    next
  end

  Account.create!(
    id:           attrs[:id],
    cedente:      attrs[:cedente],
    credor:       attrs[:credor],
    sacado:       attrs[:sacado],
    type:         "escrow",
    status:       "active",
    policy_rules: attrs[:policy_rules]
  )
  puts "   Conta #{i + 1}: #{attrs[:cedente].name}"
end

account1 = Account.find(ACCOUNT_1_ID)
account2 = Account.find(ACCOUNT_2_ID)
account3 = Account.find(ACCOUNT_3_ID)

# == LedgerEntries ==
puts "-- LedgerEntries"

ledger_seeds = [
  # Conta 1 — saldo saudável
  { account: account1, type: "CREDIT_RECEIVED", direction: "CREDIT", amount_cents: 1_200_000, status: "SETTLED",  key: "seed-a1-cr-01", description: "Antecipação FIDC — CCB-2024-001" },
  { account: account1, type: "CREDIT_RECEIVED", direction: "CREDIT", amount_cents:   800_000, status: "SETTLED",  key: "seed-a1-cr-02", description: "Antecipação FIDC — CCB-2024-002" },
  { account: account1, type: "DEBIT_EXECUTED",  direction: "DEBIT",  amount_cents:   350_000, status: "SETTLED",  key: "seed-a1-de-01", description: "TED para Distribuidora Alfa" },
  { account: account1, type: "DEBIT_RESERVED",  direction: "DEBIT",  amount_cents:   150_000, status: "PENDING",  key: "seed-a1-dr-01", description: "Reserva TED — dupla alçada pendente" },

  # Conta 2 — alto volume
  { account: account2, type: "CREDIT_RECEIVED", direction: "CREDIT", amount_cents: 2_500_000, status: "SETTLED",  key: "seed-a2-cr-01", description: "Antecipação FIDC — CCB-2024-010" },
  { account: account2, type: "DEBIT_EXECUTED",  direction: "DEBIT",  amount_cents:   900_000, status: "SETTLED",  key: "seed-a2-de-01", description: "TED para Supermercados Beta" },
  { account: account2, type: "DEBIT_EXECUTED",  direction: "DEBIT",  amount_cents:   400_000, status: "SETTLED",  key: "seed-a2-de-02", description: "TED para Supermercados Beta — 2ª remessa" },
  { account: account2, type: "DEBIT_RESERVED",  direction: "DEBIT",  amount_cents:   200_000, status: "PENDING",  key: "seed-a2-dr-01", description: "Reserva TED em análise" },

  # Conta 3 — operações menores
  { account: account3, type: "CREDIT_RECEIVED", direction: "CREDIT", amount_cents:   600_000, status: "SETTLED",  key: "seed-a3-cr-01", description: "Antecipação FIDC — CCB-2024-020" },
  { account: account3, type: "DEBIT_EXECUTED",  direction: "DEBIT",  amount_cents:   120_000, status: "SETTLED",  key: "seed-a3-de-01", description: "TED para Atacado Gama" },
  { account: account3, type: "DEBIT_REVERSED",  direction: "DEBIT",  amount_cents:    80_000, status: "REVERSED", key: "seed-a3-dv-01", description: "Estorno — TED recusado pelo SPB" }
]

ledger_seeds.each do |e|
  next if LedgerEntry.exists?(account_id: e[:account].id, idempotency_key: e[:key])

  LedgerEntry.create!(
    account:         e[:account],
    type:            e[:type],
    direction:       e[:direction],
    amount_cents:    e[:amount_cents],
    status:          e[:status],
    idempotency_key: e[:key],
    description:     e[:description]
  )
  print "."
end
puts " done"

puts "\n== Seed concluído =="
puts "   Users: #{User.count} | Participantes: #{Participant.count}"
puts "   Contas: #{Account.count} | Lançamentos: #{LedgerEntry.count}"
puts "   Login: demo@credflow.com / password123"
