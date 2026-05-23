# RabbitMQ — CredFlow

---

## Topologia

### Exchanges

| Exchange          | Tipo  | Propósito                                  |
|-------------------|-------|--------------------------------------------|
| `credflow.events` | topic | exchange principal — todos os eventos      |
| `credflow.dlx`    | topic | dead-letter — mensagens após N retries     |

### Filas e bindings

| Fila                        | Routing key pattern         | Consumer                  |
|-----------------------------|-----------------------------|---------------------------|
| `q.account.ledger-commands` | `payment.settled`           | account-service           |
|                             | `payment.failed`            | account-service           |
| `q.payment.notifications`   | `account.opened`            | payment-service           |
|                             | `installment.overdue`       | payment-service           |
| `q.receivables.events`      | `payment.settled`           | receivables-service       |
| `q.webhook.dispatch`        | `#` (todos os eventos)      | webhook-dispatcher        |
| `q.notifications.email`     | `approval.requested`        | notification-worker       |
|                             | `payment.failed`            | notification-worker       |
| `q.dead-letter`             | `dead`                      | monitoramento / alertas   |

Todas as filas são `durable: true`. Declaradas com:
```ruby
arguments: {
  'x-dead-letter-exchange'    => 'credflow.dlx',
  'x-dead-letter-routing-key' => 'dead'
}
```

---

## Envelope padrão

Todo evento publicado segue este envelope. Nunca publicar payload nu.

```json
{
  "eventId":       "uuid-v4",
  "eventType":     "payment.settled",
  "version":       "1.0",
  "occurredAt":    "2024-03-15T14:32:00Z",
  "correlationId": "uuid-v4",
  "source":        "payment-service",
  "payload":       {}
}
```

- `eventId` — uuid único por evento. Consumers usam para idempotência:
  verificam no Redis se já processaram antes de agir.
- `correlationId` — mesmo valor em toda a cadeia de uma operação.
  Permite rastrear no Jaeger: pagamento → ledger → webhook.
- `version` — para evolução sem breaking change. Consumers ignoram
  campos desconhecidos de versões futuras.

---

## Eventos por serviço

### account-service publica

#### `account.opened`
Disparado quando conta vinculada é criada com KYC aprovado.
```json
{
  "eventType": "account.opened",
  "payload": {
    "accountId":   "uuid",
    "type":        "escrow",
    "credorId":    "uuid",
    "cedenteId":   "uuid",
    "sacadoId":    "uuid",
    "policyRules": {
      "approvalRequiredAboveCents":    5000000,
      "blockedHours":                  { "start": "17:00", "end": "09:00" },
      "newBeneficiaryRequiresApproval": true,
      "dailyLimitCents":               50000000,
      "approvalThreshold":             { "required": 2, "of": 3 }
    }
  }
}
```
Consumido por: `q.payment.notifications` → payment-service carrega as regras
em memória/cache para avaliação rápida do policy engine.

#### `ledger.entry_created`
Disparado após cada inserção no ledger.
```json
{
  "eventType": "ledger.entry_created",
  "payload": {
    "entryId":        "uuid",
    "accountId":      "uuid",
    "type":           "DEBIT_EXECUTED",
    "direction":      "DEBIT",
    "amountCents":    150000,
    "paymentOrderId": "uuid",
    "status":         "SETTLED",
    "newBalanceCents": 3850000
  }
}
```
`newBalanceCents` calculado no momento da inserção — consumers não precisam
fazer query extra para saber o saldo pós-lançamento.

---

### payment-service publica

#### `approval.requested`
Disparado quando `payment_order` entra em `PENDING_APPROVAL`.
```json
{
  "eventType": "approval.requested",
  "payload": {
    "paymentOrderId":   "uuid",
    "accountId":        "uuid",
    "amountCents":      8000000,
    "reason":           "amount_threshold",
    "approversNeeded":  2,
    "approvalsReceived": 0,
    "expiresAt":        "2024-03-15T17:00:00Z",
    "beneficiaryDoc":   "12.345.678/0001-99"
  }
}
```
Consumido por: `q.notifications.email` → Mailhog envia email a cada aprovador
com link para a fila de aprovação no frontend.

#### `payment.settled`
Disparado quando SPB mock confirma liquidação.
```json
{
  "eventType": "payment.settled",
  "payload": {
    "paymentOrderId":  "uuid",
    "accountId":       "uuid",
    "amountCents":     8000000,
    "beneficiaryDoc":  "12.345.678/0001-99",
    "settledAt":       "2024-03-15T14:32:00Z",
    "spbTransactionId":"SPB-2024-XXXX"
  }
}
```
Consumido por **dois** consumers simultaneamente:
- `q.account.ledger-commands` → account-service cria `DEBIT_EXECUTED`
- `q.receivables.events` → receivables-service confere se liquida alguma parcela

#### `payment.failed`
Disparado quando SPB mock retorna erro ou TTL de aprovação expira.
```json
{
  "eventType": "payment.failed",
  "payload": {
    "paymentOrderId":  "uuid",
    "accountId":       "uuid",
    "amountCents":     8000000,
    "reason":          "spb_timeout",
    "reservedEntryId": "uuid"
  }
}
```
`reservedEntryId` é usado pelo account-service para localizar o `DEBIT_RESERVED`
e criar o `DEBIT_REVERSED` (compensação).
Consumido por: `q.account.ledger-commands` + `q.notifications.email`.

#### `payment.approval_expired`
Disparado pelo job `ExpirePendingApprovalsJob` (roda a cada 5min via Solid Queue).
```json
{
  "eventType": "payment.approval_expired",
  "payload": {
    "paymentOrderId": "uuid",
    "accountId":      "uuid",
    "amountCents":    8000000,
    "expiredAt":      "2024-03-15T17:00:00Z"
  }
}
```

---

### receivables-service publica

#### `ccb.issued`
Disparado quando CCB é emitida e installments geradas.
```json
{
  "eventType": "ccb.issued",
  "payload": {
    "ccbId":            "uuid",
    "accountId":        "uuid",
    "principalCents":   2000000,
    "discountCents":    200000,
    "installmentCount": 12,
    "firstDueDate":     "2024-04-10"
  }
}
```

#### `installment.paid`
Disparado quando parcela é marcada como paga pelo consumer de `payment.settled`.
```json
{
  "eventType": "installment.paid",
  "payload": {
    "installmentId": "uuid",
    "ccbId":         "uuid",
    "accountId":     "uuid",
    "number":        3,
    "amountCents":   166667,
    "paidAt":        "2024-06-10"
  }
}
```

#### `installment.overdue`
Disparado pelo job `OverdueDetectionJob` (cron 01:00 diário).
```json
{
  "eventType": "installment.overdue",
  "payload": {
    "installmentId": "uuid",
    "ccbId":         "uuid",
    "accountId":     "uuid",
    "number":        3,
    "amountCents":   166667,
    "paidCents":     0,
    "dueDate":       "2024-03-10",
    "daysOverdue":   5
  }
}
```
Consumido por: `q.payment.notifications` → payment-service pode bloquear
novas saídas da conta vinculada se o contrato assim definir.

#### `reconciliation.divergence_found`
Disparado pelo job `ReconciliationJob` (cron 02:00 diário) por cada divergência.
```json
{
  "eventType": "reconciliation.divergence_found",
  "payload": {
    "runId":            "uuid",
    "accountId":        "uuid",
    "referenceDate":    "2024-03-14",
    "entryId":          "uuid",
    "ledgerAmountCents": 50000,
    "spbAmountCents":    49800,
    "diffCents":         200
  }
}
```

---

## Retry e dead-letter

### Fluxo de retry
Consumer falha → `nack(requeue: false)` → mensagem vai para `credflow.dlx`
→ roteada para `q.dead-letter`.

Retry com backoff exponencial implementado no consumer antes do nack:

```ruby
# app/consumers/application_consumer.rb
def process_with_retry(delivery_info, metadata, payload)
  retry_count = metadata[:headers]&.dig('x-retry-count') || 0

  handle(JSON.parse(payload))
  channel.ack(delivery_info.delivery_tag)

rescue => e
  if retry_count >= 3
    Rails.logger.error("DLQ: #{e.message}", payload: payload)
    channel.nack(delivery_info.delivery_tag, false, false)
    return
  end

  sleep(2 ** retry_count)  # 1s, 2s, 4s

  channel.default_exchange.publish(
    payload,
    routing_key: delivery_info.routing_key,
    headers: { 'x-retry-count' => retry_count + 1 },
    correlation_id: metadata[:correlation_id]
  )
  channel.ack(delivery_info.delivery_tag)
end
```

`correlation_id` preservado no retry → trace Jaeger continua contínuo.

### Monitoramento da DLQ
O Grafana tem um painel dedicado ao tamanho de `q.dead-letter`.
Crescimento indica falha sistêmica em algum consumer.
RabbitMQ management UI: `http://localhost:15672` (credflow/credflow).

---

## Configuração Bunny (publisher)

```ruby
# config/initializers/rabbitmq.rb
RABBITMQ_CONNECTION = Bunny.new(ENV['RABBITMQ_URL']).tap(&:start)

# app/publishers/event_publisher.rb
class EventPublisher
  EXCHANGE = 'credflow.events'

  def self.publish(event_type, payload, correlation_id:, source:)
    channel  = RABBITMQ_CONNECTION.create_channel
    exchange = channel.topic(EXCHANGE, durable: true)

    envelope = {
      eventId:       SecureRandom.uuid,
      eventType:     event_type,
      version:       '1.0',
      occurredAt:    Time.current.iso8601,
      correlationId: correlation_id,
      source:        source,
      payload:       payload
    }

    exchange.publish(envelope.to_json, routing_key: event_type, persistent: true)
  ensure
    channel&.close
  end
end
```

## Configuração Sneakers (consumer)

```ruby
# config/sneakers.rb
Sneakers.configure(
  amqp:       ENV['RABBITMQ_URL'],
  exchange:   'credflow.events',
  exchange_type: :topic,
  workers:    2,
  threads:    1,
  prefetch:   1,
  timeout_job_after: 30,
  heartbeat:  10
)

# app/consumers/payment_settled_consumer.rb
class PaymentSettledConsumer
  include Sneakers::Worker

  from_queue 'q.account.ledger-commands',
    routing_key: 'payment.settled',
    durable: true,
    arguments: {
      'x-dead-letter-exchange'    => 'credflow.dlx',
      'x-dead-letter-routing-key' => 'dead'
    }

  def work(raw_message)
    envelope = JSON.parse(raw_message, symbolize_names: true)

    # idempotência: ignora se já processou
    return ack! if already_processed?(envelope[:eventId])

    LedgerWriterService.call(
      account_id:       envelope.dig(:payload, :accountId),
      type:             'DEBIT_EXECUTED',
      direction:        'DEBIT',
      amount_cents:     envelope.dig(:payload, :amountCents),
      payment_order_id: envelope.dig(:payload, :paymentOrderId),
      idempotency_key:  envelope[:eventId]
    )

    mark_processed!(envelope[:eventId])
    ack!
  rescue => e
    Rails.logger.error(e)
    reject!  # vai para DLX após N retries via ApplicationConsumer
  end
end
```
