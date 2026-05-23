# frozen_string_literal: true

class Participant < ApplicationRecord
  ROLES        = %w[cedente credor sacado].freeze
  KYC_STATUSES = %w[pending approved rejected].freeze

  DOCUMENT_FORMAT = /\A(\d{3}\.\d{3}\.\d{3}-\d{2}|\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2})\z/

  validates :role,       presence: true, inclusion: { in: ROLES }
  validates :name,       presence: true
  validates :document,   presence: true, uniqueness: true,
                         format: { with: DOCUMENT_FORMAT, message: "deve estar no formato CPF ou CNPJ" }
  validates :kyc_status, inclusion: { in: KYC_STATUSES }

  scope :kyc_approved, -> { where(kyc_status: "approved") }
end
