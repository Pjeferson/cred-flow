# frozen_string_literal: true

puts "\n== Seeding payment-service =="

# IDs fixos — devem coincidir com account-service seeds
ACCOUNT_1_ID  = "11111111-2222-3333-4444-100000000001"
ACCOUNT_2_ID  = "11111111-2222-3333-4444-100000000002"
ACCOUNT_3_ID  = "11111111-2222-3333-4444-100000000003"
REQUESTER_ID  = "dd000000-0000-0000-0000-000000000001"
APPROVER_1_ID = "cc000000-0000-0000-0000-000000000001"
APPROVER_2_ID = "cc000000-0000-0000-0000-000000000002"

puts "-- PaymentOrders (settled)"

# Ordens liquidadas — ciclo completo (draft → settled)
settled_orders = [
  { account_id: ACCOUNT_1_ID, amount_cents:  75_000, beneficiary_doc: "67.890.123/0001-41", beneficiary_name: "Distribuidora Alfa Ltda",    key: "seed-po-001", policy_action: "execute",  settled_at: 3.days.ago,   spb_id: "SPB20240501ALFA001" },
  { account_id: ACCOUNT_2_ID, amount_cents: 180_000, beneficiary_doc: "78.901.234/0001-50", beneficiary_name: "Supermercados Beta S.A.",     key: "seed-po-002", policy_action: "execute",  settled_at: 2.days.ago,   spb_id: "SPB20240502BETA001" },
  { account_id: ACCOUNT_2_ID, amount_cents: 350_000, beneficiary_doc: "78.901.234/0001-50", beneficiary_name: "Supermercados Beta S.A.",     key: "seed-po-003", policy_action: "approved", settled_at: 1.day.ago,    spb_id: "SPB20240503BETA002" },
  { account_id: ACCOUNT_3_ID, amount_cents:  45_000, beneficiary_doc: "89.012.345/0001-69", beneficiary_name: "Atacado Gama Comércio Ltda",  key: "seed-po-004", policy_action: "execute",  settled_at: 5.hours.ago,  spb_id: "SPB20240504GAMA001" }
]

settled_orders.each do |attrs|
  next if PaymentOrder.exists?(idempotency_key: attrs[:key])

  order = PaymentOrder.create!(
    account_id:         attrs[:account_id],
    amount_cents:       attrs[:amount_cents],
    beneficiary_doc:    attrs[:beneficiary_doc],
    beneficiary_name:   attrs[:beneficiary_name],
    idempotency_key:    attrs[:key],
    policy_action:      attrs[:policy_action],
    spb_transaction_id: attrs[:spb_id],
    requested_by:       REQUESTER_ID,
    expires_at:         24.hours.from_now
  )
  order.update_columns(status: "settled", settled_at: attrs[:settled_at])
  print "."
end
puts " done"

puts "-- PaymentOrders (pending_approval)"

# Ordens aguardando dupla alçada
pending_orders = [
  { account_id: ACCOUNT_1_ID, amount_cents: 250_000, beneficiary_doc: "67.890.123/0001-41", beneficiary_name: "Distribuidora Alfa Ltda",   key: "seed-po-010", expires_at: 2.hours.from_now },
  { account_id: ACCOUNT_1_ID, amount_cents: 180_000, beneficiary_doc: "78.901.234/0001-50", beneficiary_name: "Supermercados Beta S.A.",    key: "seed-po-011", expires_at: 4.hours.from_now }
]

pending_orders.each do |attrs|
  next if PaymentOrder.exists?(idempotency_key: attrs[:key])

  order = PaymentOrder.create!(
    account_id:      attrs[:account_id],
    amount_cents:    attrs[:amount_cents],
    beneficiary_doc: attrs[:beneficiary_doc],
    beneficiary_name: attrs[:beneficiary_name],
    idempotency_key: attrs[:key],
    policy_action:   "pending_approval",
    requested_by:    REQUESTER_ID,
    expires_at:      attrs[:expires_at]
  )
  order.update_column(:status, "pending_approval")
  print "."
end
puts " done"

# 1ª aprovação na primeira ordem pendente (ainda aguarda quorum)
pending1 = PaymentOrder.find_by(idempotency_key: "seed-po-010")
if pending1 && pending1.approvals.none?
  Approval.create!(
    payment_order: pending1,
    approver_id:   APPROVER_1_ID,
    decision:      "APPROVED"
  )
  puts "   Approval 1/2 criado para seed-po-010"
end

puts "-- PaymentOrders (rejected / expired / failed)"

# Ordem rejeitada (limite diário excedido)
unless PaymentOrder.exists?(idempotency_key: "seed-po-020")
  o = PaymentOrder.create!(
    account_id: ACCOUNT_3_ID, amount_cents: 1_500_000,
    beneficiary_doc: "89.012.345/0001-69", beneficiary_name: "Atacado Gama Comércio Ltda",
    idempotency_key: "seed-po-020", policy_action: "pending_approval",
    rejection_reason: "daily_limit_exceeded",
    requested_by: REQUESTER_ID, expires_at: 24.hours.from_now
  )
  o.update_column(:status, "rejected")
  puts "   rejected: R$ 15.000,00 — limite diário excedido"
end

# Ordem expirada (sem aprovadores no prazo)
unless PaymentOrder.exists?(idempotency_key: "seed-po-021")
  o = PaymentOrder.create!(
    account_id: ACCOUNT_2_ID, amount_cents: 220_000,
    beneficiary_doc: "78.901.234/0001-50", beneficiary_name: "Supermercados Beta S.A.",
    idempotency_key: "seed-po-021", policy_action: "pending_approval",
    requested_by: REQUESTER_ID, expires_at: 2.days.ago
  )
  o.update_column(:status, "expired")
  puts "   expired: R$ 2.200,00 — tempo esgotado"
end

# Ordem com falha (SPB timeout)
unless PaymentOrder.exists?(idempotency_key: "seed-po-022")
  o = PaymentOrder.create!(
    account_id: ACCOUNT_3_ID, amount_cents: 35_000,
    beneficiary_doc: "89.012.345/0001-69", beneficiary_name: "Atacado Gama Comércio Ltda",
    idempotency_key: "seed-po-022", policy_action: "execute",
    rejection_reason: "spb_timeout",
    requested_by: REQUESTER_ID, expires_at: 24.hours.from_now
  )
  o.update_column(:status, "failed")
  puts "   failed: R$ 350,00 — SPB timeout"
end

puts "\n== Seed concluído =="
puts "   PaymentOrders: #{PaymentOrder.count} | Approvals: #{Approval.count}"
by_status = PaymentOrder.group(:status).count
by_status.each { |s, n| puts "   #{s}: #{n}" }
