# frozen_string_literal: true

class ReconciliationRun < ApplicationRecord
  STATUSES = %w[running completed failed].freeze

  validates :account_id, :reference_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :reference_date, uniqueness: { scope: :account_id }

  scope :completed,    -> { where(status: "completed") }
  scope :with_divergences, -> { where(status: "completed").where("divergences_found > 0") }

  def complete!(entries_checked:, divergences_found:)
    update!(
      status:            "completed",
      entries_checked:   entries_checked,
      divergences_found: divergences_found,
      finished_at:       Time.current
    )
  end

  def fail!(message)
    update!(status: "failed", error_message: message, finished_at: Time.current)
  end
end
