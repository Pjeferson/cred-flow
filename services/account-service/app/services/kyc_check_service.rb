# frozen_string_literal: true

class KycCheckService
  include Dry::Monads[:result]

  def call(participant:)
    response = Faraday.post(
      "#{ENV.fetch("KYC_MOCK_URL")}/validate",
      { document: participant.document }.to_json,
      "Content-Type" => "application/json"
    )

    result = JSON.parse(response.body)

    participant.update!(
      kyc_status:     result["status"],
      kyc_checked_at: Time.current
    )

    Success(participant)
  rescue Faraday::Error => e
    Failure("kyc_service_unavailable: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    Failure(e.message)
  end
end
