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
    channel.ack(delivery_info.delivery_tag)
  rescue => e
    Rails.logger.error("[#{self.class.name}] Error: #{e.message}")

    if retry_count >= 3
      Rails.logger.error("[#{self.class.name}] DLQ after #{retry_count} retries: #{e.message}")
      channel.nack(delivery_info.delivery_tag, false, false)
      return
    end

    sleep(2**retry_count) # 1s, 2s, 4s

    channel.default_exchange.publish(
      payload,
      routing_key:    delivery_info.routing_key,
      headers:        { "x-retry-count" => retry_count + 1 },
      correlation_id: metadata[:correlation_id]
    )
    channel.ack(delivery_info.delivery_tag)
  end

  def handle(_envelope)
    raise NotImplementedError, "#{self.class.name} must implement #handle"
  end
end
