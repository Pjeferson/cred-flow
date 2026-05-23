# frozen_string_literal: true

class ParticipantSerializer
  include JSONAPI::Serializer

  set_type :participant

  attributes :name, :document, :role, :kyc_status, :kyc_checked_at, :created_at
end
