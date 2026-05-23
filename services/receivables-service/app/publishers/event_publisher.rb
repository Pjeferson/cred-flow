# frozen_string_literal: true

class EventPublisher
  EXCHANGE = "credflow.events"
  SOURCE   = "receivables-service"

  def self.publish(event_type, payload, correlation_id:)
    channel  = RABBITMQ_CONNECTION.create_channel
    exchange = channel.topic(EXCHANGE, durable: true)

    envelope = {
      eventId:       SecureRandom.uuid,
      eventType:     event_type,
      version:       "1.0",
      occurredAt:    Time.current.iso8601,
      correlationId: correlation_id,
      source:        SOURCE,
      payload:       payload
    }

    exchange.publish(envelope.to_json, routing_key: event_type, persistent: true)
  ensure
    channel&.close
  end
end
