# CredFlow

Plataforma de infraestrutura para operações de crédito: conta vinculada (escrow),
motor de aprovação com dupla alçada e gestão de recebíveis (CCB + parcelas).
Projeto de portfólio desenvolvido para demonstrar conceitos de mercado de capitais
e infraestrutura financeira (contexto: Vórtx/Grafeno).

---

## Stack

| Camada       | Tecnologia                    |
|--------------|-------------------------------|
| Runtime      | Ruby 3.4                      |
| Framework    | Rails 8.1 (API-only)          |
| Auth         | Devise + devise-jwt           |
| Banco        | PostgreSQL 17                 |
| Cache/Idem   | Redis 7                       |
| Mensageria   | RabbitMQ 3 (Bunny + Sneakers) |
| Jobs         | Solid Queue                   |
| State machine| AASM                          |
| Mocks        | Sinatra (Ruby)                |
| Frontend     | React 19 + Vite 6             |
| UI           | shadcn/ui + Tailwind          |
| HTTP client  | ky                            |
| Data fetch   | TanStack Query                |
| Routing      | TanStack Router               |
| Testes BE    | RSpec + FactoryBot            |
| Testes FE    | Vitest + Testing Library      |
| Infra local  | Docker Compose                |

---

## Estrutura do monorepo

```
credflow/
├── CLAUDE.md
├── docker-compose.yml
├── api-gateway/nginx.conf
├── services/
│   ├── account-service/      # participants, accounts, ledger_entries
│   ├── payment-service/      # payment_orders, approvals, policy engine
│   └── receivables-service/  # ccbs, installments, reconciliation
├── frontend/                 # React 19 + Vite 6 SPA
├── mocks/
│   ├── spb-mock/             # simula SPB/Pix/TED (Sinatra)
│   ├── kyc-mock/             # simula validação de CPF/CNPJ (Sinatra)
│   └── boleto-mock/          # gera linha digitável válida (Sinatra)
└── docs/                     # @docs/ — referenciar conforme necessário
```

Cada serviço Rails tem seu próprio banco PostgreSQL (portas 5432, 5433, 5434).
Nunca fazer JOIN cross-service. Comunicação entre serviços: HTTP síncrono para
leitura, RabbitMQ assíncrono para mudança de estado.

---

## Portas locais (Docker Compose)

| Serviço             | Porta  |
|---------------------|--------|
| api-gateway (Nginx) | 8080   |
| account-service     | 3001   |
| payment-service     | 3002   |
| receivables-service | 3003   |
| frontend (Vite)     | 5173   |
| postgres-account    | 5432   |
| postgres-payment    | 5433   |
| postgres-receivables| 5434   |
| redis               | 6379   |
| rabbitmq AMQP       | 5672   |
| rabbitmq UI         | 15672  |
| spb-mock            | 4001   |
| kyc-mock            | 4002   |
| boleto-mock         | 4003   |
| mailhog SMTP        | 1025   |
| mailhog UI          | 8025   |

---

## Ambiente de desenvolvimento

**Ruby e Node.js não estão instalados localmente.** Todo comando que precise de
Ruby ou Node deve rodar via Docker.

### Workflow de gems (serviços Rails)

```bash
# 1. Adicionar gem ao Gemfile do serviço
# 2. Rebuildar a imagem
docker compose build account-service

# 3. Rodar gerador, se necessário
docker compose run --rm account-service bundle exec rails generate <gerador>
```

O mesmo padrão vale para `payment-service` e `receivables-service`.

### Workflow de pacotes npm (frontend)

```bash
# 1. Adicionar pacote
docker compose run --rm frontend npm install <pacote>

# 2. Rebuildar a imagem
docker compose build frontend
```

### Permissões de arquivo

Geradores e `docker compose run` criam arquivos como **root**. Após qualquer
gerador, corrija com:

```bash
# Exemplo para account-service
docker run --rm -v $(pwd)/services/account-service:/app ruby:3.4-slim chown -R 1000:1000 /app
```

### Bancos de dados

O `POSTGRES_DB` cria o banco de **development** automaticamente na primeira
inicialização. O banco de **test** não é criado automaticamente:

```bash
docker compose run --rm -e RAILS_ENV=test account-service bundle exec rails db:create db:migrate
docker compose run --rm -e RAILS_ENV=test payment-service bundle exec rails db:create db:migrate
docker compose run --rm -e RAILS_ENV=test receivables-service bundle exec rails db:create db:migrate
```

### Comandos essenciais

```bash
# Subir ambiente completo
docker compose up

# Subir serviços de infraestrutura (bancos, redis, rabbit) sem aplicação
docker compose up -d postgres-account postgres-payment postgres-receivables redis rabbitmq

# Console Rails por serviço
docker compose run --rm account-service bundle exec rails console
docker compose run --rm payment-service bundle exec rails console
docker compose run --rm receivables-service bundle exec rails console

# Migrations por serviço
docker compose run --rm account-service bundle exec rails db:migrate
docker compose run --rm payment-service bundle exec rails db:migrate
docker compose run --rm receivables-service bundle exec rails db:migrate

# Testes (RAILS_ENV=test obrigatório)
docker compose run --rm -e RAILS_ENV=test account-service bundle exec rspec
docker compose run --rm -e RAILS_ENV=test payment-service bundle exec rspec
docker compose run --rm -e RAILS_ENV=test receivables-service bundle exec rspec

# Logs de um serviço
docker compose logs -f payment-service

# Frontend
docker compose run --rm frontend npm run test
docker compose run --rm frontend npm run build
```

### Validações rápidas

```bash
# CORS carregado num serviço?
docker compose run --rm account-service bundle exec rails runner \
  "puts Rails.application.config.middleware.middlewares.map { |m| m.klass.to_s }.grep(/Cors/)"

# Serviço conecta ao banco?
docker compose run --rm account-service bundle exec rails db:create

# RabbitMQ acessível?
docker compose run --rm account-service bundle exec rails runner \
  "conn = Bunny.new(ENV['RABBITMQ_URL']).tap(&:start); puts conn.status; conn.close"
```

### Gotchas importantes

**Devise-jwt em modo API (aplicado nos 3 serviços Rails):**
- `respond_to_on_destroy` deve ser sobrescrito com `(**)` para evitar 401 vazio
- `devise_for` deve ficar **fora** de qualquer bloco `namespace` — usar `path: "api/v1/auth"` diretamente
- Revogação de token é responsabilidade do middleware, não do controller

**RabbitMQ consumers (Sneakers):**
- Sneakers roda como processo separado — não é iniciado pelo Rails server
- Em dev, iniciar com: `docker compose run --rm account-service bundle exec sneakers work PaymentSettledConsumer`
- Todas as filas declaradas com `durable: true` e `x-dead-letter-exchange`

**Solid Queue:**
- Jobs agendados (cron) configurados em `config/recurring.yml`
- Em dev, o Solid Queue supervisor sobe junto com o Puma via `Procfile.dev`

---

## Convenções de código — Rails

- **Service objects** em `app/services/` — retornam `Dry::Monads::Result` (Success/Failure)
- **Consumers RabbitMQ** em `app/consumers/` — herdam de `ApplicationConsumer`
- **Publishers** em `app/publishers/` — sempre via `EventPublisher.publish(type, payload, correlation_id:)`
- **Políticas** em `app/policies/` — Pundit, uma por recurso
- **Serializers** em `app/serializers/` — jsonapi-serializer
- Controllers finos: validação de params → chama service object → serializa → responde
- Nunca atualizar `ledger_entry` — append-only. Compensações são novos registros
- Valores monetários sempre em centavos (`amount_cents` como `bigint`)
- Toda rota prefixada com `/api/v1/`
- `frozen_string_literal: true` em todos os arquivos Ruby

---

## Convenções de código — Frontend

- Organização por feature em `src/features/` (não por tipo de arquivo)
- Cada feature tem: `ComponentName.tsx`, `useFeatureName.ts`, tipos inline ou `types.ts`
- Chamadas de API centralizadas em `src/lib/api.ts`
- Estado servidor via TanStack Query — sem duplicar em Zustand
- Zustand só para estado de UI global (ex: usuário autenticado, tema)
- Componentes shadcn/ui importados de `@/components/ui/`

---

## Convenções de commit

Seguir Conventional Commits com referência de task.

**Formato:**
```
<type>: TASK-XX — <descrição em português>
```

**Exemplos:**
- `feat: TASK-01 — estrutura de diretórios do monorepo`
- `feat: TASK-09 — Devise + devise-jwt no account-service`
- `fix: TASK-21 — policy engine com race condition no quorum`
- `chore: TASK-01 — marca task concluída no backlog`

**Regras:**
- Referência da task (`TASK-XX`) vem logo após o tipo, antes do `—`
- Separador é `—` (em dash), não `-`
- Descrição sempre em **português**
- Sem parênteses em torno da referência da task

---

## Documentação de referência

| Doc | O que cobre | Consultar quando |
|-----|-------------|------------------|
| `@docs/domain.md` | Atores, termos, motor de aprovação, cenários de borda, fluxo ponta a ponta | Qualquer dúvida de comportamento de negócio |
| `@docs/data-model.md` | Schemas SQL dos 3 bancos, índices, queries de saldo, decisões de design | Criar models, migrations ou queries |
| `@docs/rabbitmq.md` | Topologia, filas, routing keys, payloads de evento, retry/DLX | Implementar publishers, consumers ou novos eventos |

---

## Domínio — termos críticos

- **Cedente**: titular da conta vinculada, solicita TEDs, cede o direito creditório
- **Credor** (FIDC): aprova TEDs acima do limite, antecipa o valor
- **Sacado**: paga os boletos das parcelas da CCB
- **Conta vinculada (escrow)**: conta com permissionamento tripartite
- **CCB**: contrato de crédito — gera cronograma de `installments`
- **Ledger**: imutável, dupla entrada — nunca campo `saldo`, sempre calculado
- **Dupla alçada**: pagamentos acima do limite exigem N aprovadores do credor
- **Conciliação**: job diário comparando ledger interno com extrato SPB mock

Ver detalhes completos em `@docs/domain.md`

---

## Eventos RabbitMQ — envelope padrão

```json
{
  "eventId": "uuid",
  "eventType": "payment.settled",
  "version": "1.0",
  "occurredAt": "ISO8601",
  "correlationId": "uuid",
  "source": "payment-service",
  "payload": {}
}
```

Exchanges: `credflow.events` (topic) · `credflow.dlx` (dead-letter)
Ver filas e routing keys em `@docs/rabbitmq.md`

---

## Regras absolutas de domínio

- Nunca escrever em tabela de outro serviço diretamente
- Nunca usar `float` para dinheiro — sempre `bigint` em centavos
- Nunca fazer `UPDATE` em `ledger_entry` — append-only
- Todo endpoint que muta estado exige `idempotency_key` no header
- Audit log em toda mudança de status de `payment_order`
- Mocks externos acessados apenas via variável de ambiente (`SPB_MOCK_URL` etc.)

---

## Backlog de tarefas

### Fase 1 — Infraestrutura base

- [x] **TASK-01**: Criar estrutura de diretórios do monorepo (`services/`, `mocks/`, `frontend/`, `api-gateway/`)
- [x] **TASK-02**: Gerar `docker-compose.yml` com todos os serviços (3 Rails + 3 Postgres + Redis + RabbitMQ + frontend + Nginx + 3 mocks + Mailhog)
- [x] **TASK-03**: Inicializar account-service Rails 8 API-only com PostgreSQL
- [x] **TASK-04**: Inicializar payment-service Rails 8 API-only com PostgreSQL
- [x] **TASK-05**: Inicializar receivables-service Rails 8 API-only com PostgreSQL
- [x] **TASK-06**: Configurar api-gateway Nginx (proxy reverso por prefixo de rota)
- [x] **TASK-07**: Inicializar frontend React 19 + Vite 6 + TypeScript + TanStack Router/Query + shadcn/ui
- [x] **TASK-08**: Configurar CORS nos três serviços Rails

### Fase 2 — Auth (account-service)

- [x] **TASK-09**: Instalar e configurar Devise + devise-jwt no account-service (User + JwtDenylist)
- [x] **TASK-10**: Endpoints de auth: `POST /api/v1/auth/sign_up`, `POST /api/v1/auth/sign_in`, `DELETE /api/v1/auth/sign_out`
- [x] **TASK-11**: Fluxo de auth no frontend (login, registro, logout, persistência de JWT)

### Fase 3 — account-service: Participantes e KYC

- [x] **TASK-12**: Model `Participant` (cedente, credor, sacado) com `kyc_status`
- [x] **TASK-13**: kyc-mock Sinatra (valida CPF/CNPJ, responde `approved`/`rejected`)
- [x] **TASK-14**: CRUD de participantes (`/api/v1/participants`) + endpoint de KYC check

### Fase 4 — account-service: Contas e Ledger

- [x] **TASK-15**: Model `Account` (conta vinculada) com `policy_rules` JSONB + validações
- [x] **TASK-16**: Model `LedgerEntry` (append-only) + `BalanceCalculator` (query de saldo e saldo disponível)
- [x] **TASK-17**: Endpoints de conta: criar, listar, saldo (`GET /api/v1/accounts/:id/balance`), extrato

### Fase 5 — RabbitMQ: setup base

- [x] **TASK-18**: Bunny + `EventPublisher` nos 3 serviços Rails (exchange `credflow.events`)
- [x] **TASK-19**: `ApplicationConsumer` base (Sneakers) com retry exponencial e dead-letter nos 3 serviços

### Fase 6 — payment-service: Motor de aprovação

- [x] **TASK-20**: Model `PaymentOrder` com state machine AASM (todos os estados e transições)
- [x] **TASK-21**: Model `Approval` (imutável após inserção, constraint `uq_approval_per_approver`)
- [x] **TASK-22**: Policy Engine — avalia `policy_rules` da conta e decide ação da order
- [x] **TASK-23**: Idempotência via Redis (check de `Idempotency-Key` header, TTL 24h)
- [x] **TASK-24**: spb-mock Sinatra (simula liquidação TED/Pix, retorna `settled` ou erro)
- [x] **TASK-25**: Endpoint criação de `PaymentOrder` + policy check automático
- [x] **TASK-26**: Endpoint de aprovação (`POST /api/v1/payment_orders/:id/approvals`) com quorum N de M
- [ ] **TASK-27**: Job `ExpirePendingApprovalsJob` (Solid Queue, a cada 5min — marca EXPIRED e compensa)
- [ ] **TASK-28**: Consumer `payment.settled` → account-service cria `DEBIT_EXECUTED`
- [ ] **TASK-29**: Consumer `payment.failed` → account-service cria `DEBIT_REVERSED` via `reservedEntryId`

### Fase 7 — receivables-service

- [ ] **TASK-30**: Model `Ccb` + `InstallmentScheduler` (gera parcelas em batch na mesma transação)
- [ ] **TASK-31**: Model `Installment` com index parcial em `(due_date) WHERE status IN ('pending', 'partially_paid')`
- [ ] **TASK-32**: Model `ReconciliationRun`
- [ ] **TASK-33**: boleto-mock Sinatra (gera linha digitável válida)
- [ ] **TASK-34**: Endpoints CCB: emitir, listar, detalhe + cronograma de installments
- [ ] **TASK-35**: Consumer `payment.settled` → reconcilia parcelas (atualiza `paid_cents` e status)
- [ ] **TASK-36**: Job `OverdueDetectionJob` (Solid Queue, cron 01:00 diário — marca OVERDUE)
- [ ] **TASK-37**: Job `ReconciliationJob` (Solid Queue, cron 02:00 diário — compara ledger com extrato SPB)

### Fase 8 — Notificações

- [ ] **TASK-38**: Consumer `approval.requested` → email via Mailhog (lista aprovadores + link)
- [ ] **TASK-39**: Consumer `payment.failed` → email de notificação ao cedente

### Fase 9 — Frontend

- [ ] **TASK-40**: Dashboard de participantes e contas vinculadas (criar, listar, ver saldo)
- [ ] **TASK-41**: Fluxo de payment order: criar pedido + tela de aprovação (dupla alçada)
- [ ] **TASK-42**: Dashboard de CCBs e cronograma de parcelas
- [ ] **TASK-43**: Extrato da conta vinculada (ledger entries com paginação)
- [ ] **TASK-44**: Painel de monitoramento (reconciliação, inadimplência, DLQ status)

### Fase 10 — Testes e Seeds

- [ ] **TASK-45**: Request specs RSpec para account-service (participants, accounts, ledger, balance)
- [ ] **TASK-46**: Request specs RSpec para payment-service (payment orders, approvals, policy engine)
- [ ] **TASK-47**: Request specs RSpec para receivables-service (CCBs, installments, reconciliation)
- [ ] **TASK-48**: Seeds realistas com Faker cobrindo o fluxo completo ponta a ponta

---

## Regras para o Claude Code

1. **Sempre rode os testes** após implementar uma tarefa. Nenhuma tarefa está concluída com testes quebrados.
2. **Peça confirmação** antes de rodar migrations destrutivas ou apagar arquivos.
3. **Uma tarefa por vez.** Não avance para a próxima sem confirmação explícita.
4. **Prefira editar** arquivos existentes a recriar do zero.
5. **Siga as convenções** definidas neste documento. Em caso de dúvida, pergunte antes de decidir.
6. **Commits atômicos** ao final de cada tarefa concluída.
7. **Marque tasks concluídas no backlog acima** (`[ ]` → `[x]`) ao finalizar cada tarefa — inclua sempre no mesmo commit da tarefa ou num commit de `chore:` imediato.
8. **Serviços são isolados** — nunca criar dependência de código entre `account-service`, `payment-service` e `receivables-service`. Comunicação apenas via HTTP ou RabbitMQ.
