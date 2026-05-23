# frozen_string_literal: true

module Idempotent
  extend ActiveSupport::Concern

  IDEMPOTENCY_TTL = 24.hours.to_i

  included do
    before_action :check_idempotency_key, only: :create
  end

  private

  def check_idempotency_key
    @idempotency_key = request.headers["Idempotency-Key"].presence
    unless @idempotency_key
      render json: { error: "Idempotency-Key header obrigatório" }, status: :unprocessable_entity
      return
    end

    cached = idempotency_redis.get(idempotency_cache_key)
    return unless cached

    data = JSON.parse(cached, symbolize_names: true)
    render json: data[:body], status: data[:status]
  end

  def cache_idempotency_response(body, status)
    return unless @idempotency_key

    idempotency_redis.setex(
      idempotency_cache_key,
      IDEMPOTENCY_TTL,
      { status: status, body: body }.to_json
    )
  end

  def idempotency_cache_key
    "idempotency:#{self.class.name.underscore}:#{@idempotency_key}"
  end

  def idempotency_redis
    @idempotency_redis ||= Redis.new(url: ENV.fetch("REDIS_URL"))
  end
end
