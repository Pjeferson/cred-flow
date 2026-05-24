# frozen_string_literal: true

puts "\n== Seeding receivables-service =="

# IDs fixos — devem coincidir com account-service seeds
ACCOUNT_1_ID = "11111111-2222-3333-4444-100000000001"
ACCOUNT_2_ID = "11111111-2222-3333-4444-100000000002"
ACCOUNT_3_ID = "11111111-2222-3333-4444-100000000003"

# == CCBs + parcelas ==
puts "-- CCBs"

ccb_definitions = [
  # Conta 1 — CCB ativa, parcelas futuras
  {
    account_id:        ACCOUNT_1_ID,
    principal_cents:   1_200_000,
    discount_cents:       60_000,
    annual_rate:          "0.14",
    installment_count:        12,
    first_due_date:    1.month.from_now.to_date,
    status:            "active"
  },
  # Conta 2 — CCB ativa, iniciada há 1 ano (parcelas overdue existem)
  {
    account_id:        ACCOUNT_2_ID,
    principal_cents:   2_400_000,
    discount_cents:      120_000,
    annual_rate:          "0.12",
    installment_count:        24,
    first_due_date:    12.months.ago.to_date,
    status:            "active"
  },
  # Conta 3 — CCB menor, 6 parcelas, iniciada há 2 meses
  {
    account_id:        ACCOUNT_3_ID,
    principal_cents:     480_000,
    discount_cents:       24_000,
    annual_rate:          "0.16",
    installment_count:         6,
    first_due_date:    2.months.ago.to_date,
    status:            "active"
  }
]

ccbs = []
ccb_definitions.each_with_index do |attrs, i|
  existing = Ccb.find_by(account_id: attrs[:account_id], principal_cents: attrs[:principal_cents])
  if existing
    ccbs << existing
    puts "   CCB #{i + 1} já existe (#{existing.installments.count} parcelas)"
    next
  end

  ccb = Ccb.create!(attrs)
  result = InstallmentScheduler.new.call(ccb)
  if result.success?
    ccbs << ccb
    puts "   CCB #{i + 1}: R$ #{format("%.2f", attrs[:principal_cents] / 100.0)} — #{attrs[:installment_count]}x"
  else
    puts "   ERRO CCB #{i + 1}: #{result.failure}"
  end
end

# Atualizar status das parcelas vencidas (due_date no passado)
puts "-- Atualizando parcelas vencidas"
total_overdue = 0
ccbs.each do |ccb|
  count = Installment
    .where(ccb: ccb, status: "pending")
    .where("due_date < ?", Date.current)
    .update_all(status: "overdue")
  total_overdue += count
end
puts "   #{total_overdue} parcelas marcadas como overdue"

# Parcialmente pagar as 2 primeiras vencidas de cada CCB (simula inadimplência parcial)
partial_count = 0
ccbs.each do |ccb|
  ccb.installments.overdue.order(:due_date).first(2).each do |inst|
    inst.update_columns(
      paid_cents: inst.amount_cents / 2,
      status:     "partially_paid"
    )
    partial_count += 1
  end
end
puts "   #{partial_count} parcelas com pagamento parcial"

# Marcar algumas parcelas como pagas (antes das overdue)
paid_count = 0
ccbs.each do |ccb|
  ccb.installments
     .where("due_date < ?", 3.months.ago.to_date)
     .where(status: "overdue")
     .order(:due_date)
     .first(3)
     .each do |inst|
    inst.update_columns(
      paid_cents: inst.amount_cents,
      status:     "paid",
      paid_at:    inst.due_date + 2.days
    )
    paid_count += 1
  end
end
puts "   #{paid_count} parcelas marcadas como paid"

# == ReconciliationRuns ==
puts "-- ReconciliationRuns"

account_ids = [ACCOUNT_1_ID, ACCOUNT_2_ID, ACCOUNT_3_ID]
run_count = 0

7.downto(1) do |days_ago|
  account_ids.each_with_index do |account_id, idx|
    ref_date = days_ago.days.ago.to_date
    next if ReconciliationRun.exists?(account_id: account_id, reference_date: ref_date)

    ran_at = days_ago.days.ago.beginning_of_day + 2.hours

    run = ReconciliationRun.create!(
      account_id:     account_id,
      reference_date: ref_date,
      status:         "running",
      ran_at:         ran_at
    )

    # Simular divergência na conta 1, há 3 dias
    divergences = (days_ago == 3 && idx == 0) ? 2 : 0

    # Simular falha na conta 2, há 5 dias
    if days_ago == 5 && idx == 1
      run.update_columns(
        status:        "failed",
        error_message: "spb_connection_timeout",
        finished_at:   ran_at + 3.minutes
      )
    else
      run.update_columns(
        status:            "completed",
        entries_checked:   rand(8..25),
        divergences_found: divergences,
        finished_at:       ran_at + rand(2..7).minutes
      )
    end

    run_count += 1
  end
end
puts "   #{run_count} reconciliation runs criados"

puts "\n== Seed concluído =="
puts "   CCBs: #{Ccb.count} | Installments: #{Installment.count}"
puts "   Overdue: #{Installment.overdue.count} | Partially paid: #{Installment.partially_paid.count}"
puts "   ReconciliationRuns: #{ReconciliationRun.count} (com divergências: #{ReconciliationRun.with_divergences.count})"
