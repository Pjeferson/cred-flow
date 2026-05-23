# CredFlow

Infraestrutura de crédito e pagamentos implementada do zero — conta vinculada com permissionamento tripartite, motor de aprovação configurável por regras, gestão de recebíveis e conciliação financeira.

O projeto simula o back-office de uma plataforma de crédito: credores (FIDCs, securitizadoras) que precisam operar contas vinculadas com governança real sobre as saídas, cedentes que antecipam recebíveis, e sacados que pagam parcelas de CCBs. Todo o ambiente roda localmente — sem dependências externas — com serviços mock que reproduzem o comportamento do SPB, KYC e emissão de boletos.

---

## O que está implementado

### Conta vinculada (escrow)
Conta bancária com três partes permissionadas: o cedente é o titular, o credor controla as saídas acima do limite, o sacado paga os boletos. O saldo nunca é um campo no banco — é sempre calculado a partir de um ledger imutável de dupla entrada. Qualquer tentativa de débito passa por reserva prévia; se a liquidação falhar, a reserva é revertida automaticamente.

### Motor de aprovação com dupla alçada
Toda ordem de pagamento passa por um policy engine antes de ser executada. As regras são configuradas por conta (em JSONB) e avaliadas em sequência: valor acima do limite exige aprovação de N de M aprovadores do credor, horário fora da janela bancária agenda o pagamento para o próximo dia útil, beneficiário novo dispara revisão obrigatória, limite diário excedido rejeita com motivo registrado. Pagamentos em aprovação têm TTL — se o quorum não for atingido no prazo, o sistema compensa automaticamente.

### Gestão de recebíveis (CCB)
A emissão de uma CCB gera todo o cronograma de parcelas em uma única transação atômica. Um job diário detecta inadimplência, calcula juros de mora sobre o saldo devedor (não sobre o valor cheio) e publica eventos para o credor agir. Suporte a pagamento parcial de parcela.

### Conciliação financeira
Job noturno que compara cada lançamento do ledger interno com o que o SPB mock reporta como efetivamente liquidado. Divergências são registradas com valor esperado, valor recebido e diferença — prontas para investigação.

### Observabilidade
Tracing distribuído com OpenTelemetry em todos os serviços — um `correlation_id` atravessa toda a cadeia de um pagamento, do request HTTP até o evento no RabbitMQ. Logs estruturados, métricas Prometheus e dashboards Grafana com fila de aprovações pendentes e SLA de liquidação.

---

## Arquitetura

Três serviços Rails independentes, cada um com seu próprio banco PostgreSQL. Comunicação síncrona via HTTP para leitura, assíncrona via RabbitMQ para mudança de estado. Um Nginx roteia o tráfego por prefixo de path — o frontend fala apenas com `localhost:8080`.

```
┌─────────────────────────────────────────────┐
│                  Frontend                    │
│            React 19 + Vite 6                 │
└───────────────────┬─────────────────────────┘
                    │
             ┌──────▼──────┐
             │ API Gateway  │
             │    Nginx     │
             └──┬─────┬──┬─┘
                │     │  │
    ┌───────────▼─┐ ┌─▼──────────┐ ┌─▼──────────────────┐
    │   account   │ │  payment   │ │    receivables     │
    │   service   │ │  service   │ │     service        │
    │             │ │            │ │                    │
    │ participants│ │pmt_orders  │ │ ccbs               │
    │ accounts    │ │ approvals  │ │ installments       │
    │ ledger      │ │            │ │ reconciliation     │
    └──────┬──────┘ └─────┬──────┘ └────────┬───────────┘
           │              │                  │
           └──────────────▼──────────────────┘
                    ┌─────────────┐
                    │  RabbitMQ   │
                    │topic exchange│
                    └─────────────┘
```

---

## Mocks — sem dependências externas

Todos os serviços externos são substituídos por implementações Rails que reproduzem o comportamento real:

| Mock | O que simula | Detalhe |
|---|---|---|
| `spb-mock` | Sistema de Pagamentos Brasileiro | Liquidação com delay configurável, cenários de timeout e falha por rota |
| `kyc-mock` | Validação de identidade (CPF/CNPJ) | Aprovação ou recusa baseada em regras por documento |
| `boleto-mock` | Emissão de boletos bancários | Gera linha digitável com dígitos verificadores válidos |
| `mailhog` | SMTP | Captura emails de notificação — interface em `localhost:8025` |

A escolha por implementar os mocks como serviços reais (e não stubs de teste) demonstra o protocolo de integração, não a dependência de um parceiro externo.

---

## Stack

| Camada | Tecnologia |
|---|---|
| Backend | Ruby 3.4 · Rails 8.1 API-only |
| Autenticação | Devise + devise-jwt |
| Banco de dados | PostgreSQL 17 (instância por serviço) |
| Cache / Idempotência | Redis 7 |
| Mensageria | RabbitMQ 3 · Bunny (publisher) · Sneakers (consumer) |
| Jobs assíncronos | Solid Queue |
| State machine | AASM |
| Frontend | React 19 · Vite 6 · TanStack Query · TanStack Router |
| UI | shadcn/ui · Tailwind CSS |
| Tracing | OpenTelemetry · Jaeger |
| Testes | RSpec · FactoryBot · Webmock |
| Infra local | Docker Compose |

---

## Rodando localmente

**Pré-requisitos:** Docker e Docker Compose.

```bash
git clone https://github.com/seu-usuario/credflow
cd credflow

cp .env.example .env
docker compose up
```

Aguarde todos os serviços subirem (~30s na primeira vez). Em seguida:

```bash
# migrar os bancos
docker compose exec account-service rails db:migrate
docker compose exec payment-service rails db:migrate
docker compose exec receivables-service rails db:migrate

# popular com dados de exemplo
docker compose exec account-service rails db:seed
```

| Interface | URL |
|---|---|
| Frontend | http://localhost:5173 |
| API Gateway | http://localhost:8080 |
| RabbitMQ UI | http://localhost:15672 |
| Mailhog | http://localhost:8025 |
| SPB mock | http://localhost:4001 |

---

## Conceitos financeiros implementados

Para quem não é familiar com o domínio:

- **Conta vinculada (escrow)** — conta bancária onde os recursos ficam sob controle compartilhado entre as partes de uma operação de crédito. O titular pode solicitar saídas, mas o credor precisa aprovar as acima do limite.

- **CCB (Cédula de Crédito Bancário)** — instrumento jurídico que formaliza uma operação de crédito, com valor, taxa de juros e cronograma de parcelas.

- **Antecipação de recebíveis** — uma empresa que tem R$ 2M a receber em 12 meses "vende" esses recebíveis para um fundo (com desconto) e recebe o dinheiro agora. O fundo recebe as parcelas diretamente.

- **Dupla alçada** — controle de governança onde pagamentos acima de certo valor precisam de mais de um aprovador. Comum em tesouraria corporativa para reduzir risco de fraude interna.

- **Ledger de dupla entrada** — forma contábil de registrar movimentações: cada evento tem dois lados (débito e crédito). O saldo é sempre calculado, nunca armazenado — impossível de adulterar sem deixar rastro.

---

## Estrutura do repositório

```
credflow/
├── services/
│   ├── account-service/      # participantes, contas, ledger
│   ├── payment-service/      # ordens de pagamento, motor de aprovação
│   └── receivables-service/  # CCBs, parcelas, conciliação
├── frontend/                 # SPA React
├── mocks/
│   ├── spb-mock/
│   ├── kyc-mock/
│   └── boleto-mock/
├── api-gateway/              # configuração Nginx
├── docs/                     # modelo de dados, domínio, eventos
└── docker-compose.yml
```
