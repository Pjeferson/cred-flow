# frozen_string_literal: true

unless Rails.env.test?
  RABBITMQ_CONNECTION = Bunny.new(ENV.fetch("RABBITMQ_URL")).tap(&:start)
end
