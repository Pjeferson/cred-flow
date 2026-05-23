# frozen_string_literal: true

module Api
  module V1
    class ParticipantsController < BaseController
      def index
        participants = Participant.all.order(created_at: :desc)
        render json: ParticipantSerializer.new(participants).serializable_hash
      end

      def show
        render json: ParticipantSerializer.new(participant).serializable_hash
      end

      def create
        participant = Participant.new(participant_params)

        if participant.save
          render json: ParticipantSerializer.new(participant).serializable_hash,
                 status: :created
        else
          render_errors(participant.errors.full_messages)
        end
      end

      def kyc_check
        result = KycCheckService.new.call(participant: participant)

        if result.success?
          render json: ParticipantSerializer.new(result.value!).serializable_hash
        else
          render_error(result.failure, status: :service_unavailable)
        end
      end

      private

      def participant
        @participant ||= Participant.find(params[:id])
      end

      def participant_params
        params.require(:participant).permit(:name, :document, :role)
      end
    end
  end
end
