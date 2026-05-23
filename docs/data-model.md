# Modelo de dados — CredFlow

Cada serviço tem seu próprio banco PostgreSQL. Nunca fazer JOIN cross-service.
Comunicação entre serviços via HTTP (leitura) ou eventos RabbitMQ (mudança de estado).

---

## account-service

### `participants`
Cedentes, credores e sacados. A mesma empresa pode ter papéis diferentes
em operações distintas — o papel fica na relação com a conta, não no participante.

```sql
CREATE TABLE participants (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role        VARCHAR NOT NULL CHECK (role IN ('cedente', 'credor', 'sacado')),
  document    VARCHAR(18) NOT NULL UNIQUE,  -- CPF ou CNPJ formatado
  name        VARCHAR NOT NULL,
  kyc_status  VARCHAR NOT NULL DEFAULT 'pending'
              CHECK (kyc_status IN ('pending', 'approved', 'rejected')),
  kyc_checked_at TIMESTAMP,
  created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);
```

Nenhuma conta pode ser aberta com participante em `kyc_status != 'approved'`.

### `accounts`
A conta vinculada. O campo `policy_rules` é o coração do motor de aprovação.

```sql
CREATE TABLE accounts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type        VARCHAR NOT NULL CHECK (type IN ('escrow', 'empresa')),
  cedente_id  UUID NOT NULL REFERENCES participants(id),
  credor_id   UUID NOT NULL REFERENCES participants(id),
  sacado_id   UUID REFERENCES participants(id),  -- nullable em conta empresa
  status      VARCHAR NOT NULL DEFAULT 'active'
              CHECK (status IN ('active', 'blocked', 'closed')),
  policy_rules JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- policy_rules esperado:
-- {
--   "approval_required_above_cents": 5000000,
--   "blocked_hours": { "start": "17:00", "end": "09:00" },
--   "new_beneficiary_requires_approval": true,
--   "daily_limit_cents": 50000000,
--   "approval_threshold": { "required": 2, "of": 3 }
-- }

CREATE INDEX idx_accounts_cedente ON accounts(cedente_id);
CREATE INDEX idx_accounts_credor  ON accounts(credor_id);
```

### `ledger_entries`
Tabela mais crítica do sistema. **Append-only — nunca UPDATE ou DELETE.**
O saldo é sempre calculado lendo esta tabela.

```sql
CREATE TABLE ledger_entries (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id       UUID NOT NULL REFERENCES accounts(id),
  type             VARCHAR NOT NULL CHECK (type IN (
                     'CREDIT_ANTECIPATION',
                     'CREDIT_RECEIVED',
                     'DEBIT_RESERVED',
                     'DEBIT_EXECUTED',
                     'DEBIT_REVERSED'
                   )),
  direction        VARCHAR NOT NULL CHECK (direction IN ('CREDIT', 'DEBIT')),
  amount_cents     BIGINT NOT NULL CHECK (amount_cents > 0),
  status           VARCHAR NOT NULL DEFAULT 'SETTLED'
                   CHECK (status IN ('SETTLED', 'PENDING', 'REVERSED')),
  payment_order_id UUID,               -- FK para payment-service (sem constraint)
  idempotency_key  VARCHAR NOT NULL,
  description      TEXT,
  created_at       TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_ledger_idempotency UNIQUE (account_id, idempotency_key)
);

CREATE INDEX idx_ledger_account_status ON ledger_entries(account_id, status);
CREATE INDEX idx_ledger_created        ON ledger_entries(account_id, created_at DESC);
```

**Query de saldo (usada em `BalanceCalculator`):**
```sql
SELECT
  COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_cents ELSE 0 END), 0) -
  COALESCE(SUM(CASE WHEN direction = 'DEBIT'  THEN amount_cents ELSE 0 END), 0)
  AS balance_cents
FROM ledger_entries
WHERE account_id = $1
  AND status = 'SETTLED';
```

**Query de saldo disponível (desconta reservas pendentes):**
```sql
SELECT
  COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_cents ELSE 0 END), 0) -
  COALESCE(SUM(CASE WHEN direction = 'DEBIT'  THEN amount_cents ELSE 0 END), 0)
  AS available_cents
FROM ledger_entries
WHERE account_id = $1
  AND status IN ('SETTLED', 'PENDING');  -- inclui reservas como débito
```

---

## payment-service

### `payment_orders`
State machine central do serviço. Cada ordem passa pelos estados em sequência
— nunca pula nem volta.

```sql
CREATE TABLE payment_orders (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id       UUID NOT NULL,         -- FK lógica para account-service
  requested_by     UUID NOT NULL,         -- participant_id do cedente
  amount_cents     BIGINT NOT NULL CHECK (amount_cents > 0),
  beneficiary_doc  VARCHAR(18) NOT NULL,  -- CPF ou CNPJ do destinatário
  beneficiary_name VARCHAR,
  status           VARCHAR NOT NULL DEFAULT 'DRAFT' CHECK (status IN (
                     'DRAFT',
                     'POLICY_CHECK',
                     'PENDING_APPROVAL',
                     'SCHEDULED',
                     'APPROVED',
                     'EXECUTING',
                     'SETTLED',
                     'REJECTED',
                     'FAILED',
                     'EXPIRED'
                   )),
  policy_action    VARCHAR,               -- razão da decisão do policy engine
  rejection_reason VARCHAR,              -- motivo de REJECTED / FAILED / EXPIRED
  spb_transaction_id VARCHAR,            -- ID retornado pelo SPB mock
  idempotency_key  VARCHAR NOT NULL UNIQUE,
  scheduled_for    TIMESTAMP,            -- preenchido quando status = SCHEDULED
  expires_at       TIMESTAMP,            -- TTL da aprovação (quando PENDING_APPROVAL)
  executed_at      TIMESTAMP,
  settled_at       TIMESTAMP,
  created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_account_status ON payment_orders(account_id, status);
CREATE INDEX idx_orders_expires        ON payment_orders(expires_at)
  WHERE status = 'PENDING_APPROVAL';    -- index parcial — só orders pendentes
```

**Estados e transições (AASM):**
```ruby
# app/models/payment_order.rb
aasm column: :status do
  state :draft, initial: true
  state :policy_check, :pending_approval, :scheduled
  state :approved, :executing, :settled
  state :rejected, :failed, :expired

  event :start_policy_check  { transitions from: :draft,             to: :policy_check }
  event :pend_approval       { transitions from: :policy_check,      to: :pending_approval }
  event :schedule            { transitions from: :policy_check,      to: :scheduled }
  event :approve             { transitions from: :pending_approval,  to: :approved }
  event :reject              { transitions from: :pending_approval,  to: :rejected }
  event :expire              { transitions from: :pending_approval,  to: :expired }
  event :start_execution     { transitions from: [:approved, :scheduled], to: :executing }
  event :settle              { transitions from: :executing,         to: :settled }
  event :fail                { transitions from: :executing,         to: :failed }
end
```

### `approvals`
Uma linha por aprovador que age sobre uma `payment_order`.
Imutável após inserção — decisões não são alteradas, são registradas.

```sql
CREATE TABLE approvals (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_order_id UUID NOT NULL REFERENCES payment_orders(id),
  approver_id      UUID NOT NULL,    -- participant_id do aprovador (credor)
  decision         VARCHAR NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED')),
  ip_address       INET,
  user_agent       TEXT,
  decided_at       TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_approval_per_approver UNIQUE (payment_order_id, approver_id)
);

CREATE INDEX idx_approvals_order ON approvals(payment_order_id, decision);
```

**Query de quorum (usada em `ApprovalStateMachine`):**
```sql
SELECT COUNT(*) >= $2 AS quorum_reached  -- $2 = threshold required
FROM approvals
WHERE payment_order_id = $1
  AND decision = 'APPROVED';
```

Um único `REJECTED` bloqueia — verificado antes de checar o quorum.

---

## receivables-service

### `ccbs`
Contrato de crédito. O `discount_cents` é calculado na emissão e gravado —
nunca recalculado. Representa a receita do credor e o custo do cedente.

```sql
CREATE TABLE ccbs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id       UUID NOT NULL,     -- FK lógica para account-service
  principal_cents  BIGINT NOT NULL CHECK (principal_cents > 0),
  discount_cents   BIGINT NOT NULL DEFAULT 0,  -- deságio (custo da antecipação)
  net_cents        BIGINT NOT NULL,            -- principal - discount (valor liberado)
  annual_rate      DECIMAL(5,4) NOT NULL,      -- ex: 0.1800 = 18% a.a.
  installment_count INT NOT NULL CHECK (installment_count > 0),
  first_due_date   DATE NOT NULL,
  status           VARCHAR NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'settled', 'defaulted', 'cancelled')),
  issued_at        TIMESTAMP NOT NULL DEFAULT NOW(),
  settled_at       TIMESTAMP
);

CREATE INDEX idx_ccbs_account ON ccbs(account_id, status);
```

### `installments`
Parcelas geradas automaticamente na emissão da CCB.
Criadas em batch na mesma transação que a CCB — atomicidade garantida.

```sql
CREATE TABLE installments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ccb_id      UUID NOT NULL REFERENCES ccbs(id),
  number      INT NOT NULL,              -- 1, 2, 3... até installment_count
  amount_cents BIGINT NOT NULL,
  paid_cents  BIGINT NOT NULL DEFAULT 0,
  due_date    DATE NOT NULL,
  paid_at     DATE,
  status      VARCHAR NOT NULL DEFAULT 'pending' CHECK (status IN (
                'pending',
                'partially_paid',
                'paid',
                'overdue'
              )),
  created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_installment_number UNIQUE (ccb_id, number)
);

CREATE INDEX idx_installments_ccb     ON installments(ccb_id, status);
CREATE INDEX idx_installments_due     ON installments(due_date)
  WHERE status IN ('pending', 'partially_paid');  -- index parcial para o job de inadimplência
```

**Cálculo de parcelas (em `InstallmentScheduler`):**
```ruby
def generate_schedule(ccb)
  (1..ccb.installment_count).map do |n|
    {
      ccb_id:       ccb.id,
      number:       n,
      amount_cents: (ccb.principal_cents / ccb.installment_count.to_f).ceil,
      due_date:     ccb.first_due_date + (n - 1).months,
      status:       'pending'
    }
  end
end
```

### `reconciliation_runs`
Registro de cada execução do job de conciliação.
`divergences_found > 0` com `status = 'completed'` → investigação manual necessária.

```sql
CREATE TABLE reconciliation_runs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id        UUID NOT NULL,
  reference_date    DATE NOT NULL,
  entries_checked   INT NOT NULL DEFAULT 0,
  divergences_found INT NOT NULL DEFAULT 0,
  status            VARCHAR NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'completed', 'failed')),
  error_message     TEXT,
  ran_at            TIMESTAMP NOT NULL DEFAULT NOW(),
  finished_at       TIMESTAMP,

  CONSTRAINT uq_reconciliation_date UNIQUE (account_id, reference_date)
);

CREATE INDEX idx_reconciliation_account ON reconciliation_runs(account_id, reference_date DESC);
```

---

## Decisões de design

### Valores monetários como BIGINT (centavos)
Aritmética de ponto flutuante gera erros em dinheiro:
`0.1 + 0.2 = 0.30000000000000004`. Guardar tudo em centavos como inteiro
elimina o problema. Conversão para reais só na camada de apresentação.

### FKs lógicas entre serviços
`payment_orders.account_id` referencia `accounts.id` do account-service,
mas **sem constraint de FK no banco** — são bancos separados. A integridade
é garantida pela sequência de criação (conta precisa existir antes do pagamento)
e pelo evento `account.opened` que o payment-service consome.

### Append-only em ledger_entries
Sem `updated_at`. Nenhuma linha é atualizada ou deletada. Correções são
novos lançamentos de compensação. Isso garante auditoria real — o histórico
completo existe e é imutável.

### Index parcial em installments
```sql
WHERE status IN ('pending', 'partially_paid')
```
O job de inadimplência (roda todo dia) precisa só das parcelas não pagas.
Index parcial reduz o tamanho do índice e acelera a query.

### Index parcial em payment_orders
```sql
WHERE status = 'PENDING_APPROVAL'
```
O job de expiração (roda a cada 5min) precisa só das ordens aguardando aprovação.
Mesma lógica — índice menor, query mais rápida.

### JSONB em policy_rules
As regras mudam por contrato e por cliente. Guardar como JSONB em vez de
colunas separadas evita migrações a cada novo tipo de regra. O policy engine
lê e interpreta o JSON em tempo de execução. Validação do schema do JSONB
feita na camada de aplicação (não no banco).
