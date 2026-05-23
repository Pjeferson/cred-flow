# frozen_string_literal: true

Sneakers.configure(
  amqp:              ENV.fetch("RABBITMQ_URL"),
  exchange:          "credflow.events",
  exchange_type:     :topic,
  workers:           2,
  threads:           1,
  prefetch:          1,
  timeout_job_after: 30,
  heartbeat:         10
)
