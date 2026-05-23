# frozen_string_literal: true

class ReconciliationJob < ApplicationJob
  queue_as :default

  def perform(reference_date = Date.yesterday.iso8601)
    account_ids = Ccb.distinct.pluck(:account_id)
    account_ids.each { |id| reconcile_account(id, reference_date) }
  end

  private

  def reconcile_account(account_id, reference_date)
    run = ReconciliationRun.create!(account_id: account_id, reference_date: reference_date)

    ledger_result = AccountServiceClient.new.fetch_ledger_entries(
      account_id, type: "DEBIT_EXECUTED", date: reference_date
    )
    spb_result = SpbClient.new.fetch_statement(account_id: account_id, date: reference_date)

    unless ledger_result.success? && spb_result.success?
      run.fail!("#{ledger_result.failure if ledger_result.failure?} #{spb_result.failure if spb_result.failure?}".strip)
      return
    end

    ledger_entries  = ledger_result.value!
    spb_transactions = spb_result.value!

    divergences = compare(ledger_entries, spb_transactions)

    run.complete!(entries_checked: ledger_entries.size, divergences_found: divergences.size)

    divergences.each { |d| publish_divergence(run, account_id, reference_date, d) }
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info("[ReconciliationJob] Already ran for account #{account_id} on #{reference_date}")
  rescue => e
    run&.fail!(e.message)
    Rails.logger.error("[ReconciliationJob] account #{account_id}: #{e.message}")
  end

  # Compara pelo payment_order_id como chave de correlação.
  # Divergência = entrada no ledger sem correspondência no SPB ou com valor diferente.
  def compare(ledger_entries, spb_transactions)
    spb_index = spb_transactions.index_by { |t| t[:spb_transaction_id] }

    divergences = []

    ledger_entries.each do |entry|
      spb_tx = spb_index[entry[:payment_order_id]]

      if spb_tx.nil?
        divergences << { entry: entry, spb_tx: nil,
                         ledger_amount: entry[:amount_cents], spb_amount: 0 }
      elsif spb_tx[:amount_cents] != entry[:amount_cents]
        divergences << { entry: entry, spb_tx: spb_tx,
                         ledger_amount: entry[:amount_cents], spb_amount: spb_tx[:amount_cents] }
      end
    end

    divergences
  end

  def publish_divergence(run, account_id, reference_date, divergence)
    EventPublisher.publish(
      "reconciliation.divergence_found",
      {
        runId:             run.id,
        accountId:         account_id,
        referenceDate:     reference_date,
        entryId:           divergence.dig(:entry, :id),
        ledgerAmountCents: divergence[:ledger_amount],
        spbAmountCents:    divergence[:spb_amount],
        diffCents:         (divergence[:ledger_amount] - divergence[:spb_amount]).abs
      },
      correlation_id: SecureRandom.uuid
    )
  end
end
