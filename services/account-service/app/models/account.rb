# frozen_string_literal: true

class Account < ApplicationRecord
  # 'type' é campo de domínio (escrow/empresa), não STI
  self.inheritance_column = nil

  TYPES    = %w[escrow empresa].freeze
  STATUSES = %w[active blocked closed].freeze

  belongs_to :cedente, class_name: "Participant", foreign_key: :cedente_id
  belongs_to :credor,  class_name: "Participant", foreign_key: :credor_id
  belongs_to :sacado,  class_name: "Participant", foreign_key: :sacado_id, optional: true

  has_many :ledger_entries, dependent: :restrict_with_error

  validates :type,   presence: true, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :policy_rules, presence: true
  validate  :participants_must_be_kyc_approved
  validate  :sacado_required_for_escrow

  scope :active, -> { where(status: "active") }

  private

  def participants_must_be_kyc_approved
    [cedente, credor, sacado].compact.each do |p|
      next if p.kyc_status == "approved"

      errors.add(:base, "#{p.role} #{p.name} não possui KYC aprovado")
    end
  end

  def sacado_required_for_escrow
    return unless type == "escrow"
    return if sacado_id.present?

    errors.add(:sacado_id, "é obrigatório para conta escrow")
  end
end
