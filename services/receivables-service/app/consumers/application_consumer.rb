# frozen_string_literal: true

class ApplicationConsumer
  include Sneakers::Worker

  def work_with_params(payload, delivery_info, metadata)
    process_with_retry(delivery_info, metadata, payload)
  end

  private

  def process_with_retry(delivery_info, metadata, payload)
    retry_count = (metadata[:headers]&.dig("x-retry-count") || 0).to_i

    handle(JSON.parse(payload, symbolize_names: true))
    ack!
  rescue => e
    Rails.logger.error("[#{self.class.name}] Error: #{e.message}")

    if retry_count >= 3
      Rails.logger.error("[#{self.class.name}] DLQ after #{retry_count} retries: #{e.message}")
      nack!
      return
    end

    sleep(2**retry_count) # 1s, 2s, 4s

    delivery_info.channel.default_exchange.publish(
      payload,
      routing_key:    delivery_info.routing_key,
      headers:        { "x-retry-count" => retry_count + 1 },
      correlation_id: metadata[:correlation_id]
    )
    ack!
  end

  def handle(_envelope)
    raise NotImplementedError, "#{self.class.name} must implement #handle"
  end
end
