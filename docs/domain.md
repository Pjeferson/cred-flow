# Domínio — CredFlow

Contexto de negócio: o CredFlow simula a infraestrutura de uma empresa que provê para credores (FIDCs, securitizadoras, fintechs de crédito)
que precisam operar contas vinculadas, executar pagamentos com governança e
gerenciar o ciclo de vida de recebíveis.

---

## Os três atores

### Cedente
Empresa que possui direitos creditórios futuros (ex: uma construtora que tem
R$ 2M a receber em 12 parcelas) e quer antecipar esse valor agora.

- É o **titular** da conta vinculada (escrow)
- Pode visualizar saldo e extrato
- Pode **solicitar** TEDs de saída, mas não executá-las sozinho acima do limite
- Cede o direito creditório ao credor em troca de liquidez imediata

### Credor
FIDC, securitizadora ou fintech de crédito que compra o direito creditório
e adianta o dinheiro ao cedente (com deságio = taxa de juros embutida).

- Tem **poder de veto** sobre saídas da conta vinculada acima do limite
- É o aprovador na dupla alçada
- Recebe as parcelas pagas pelo sacado diretamente na conta vinculada
- Configura as `policy_rules` da conta no momento da abertura

### Sacado
Empresa ou pessoa que deve pagar as parcelas originárias da CCB.

- Não precisa saber que houve cessão de crédito
- Recebe boletos e paga normalmente
- Cada pagamento entra diretamente na conta vinculada (não no cedente)

---

## Termos do domínio

### CCB (Cédula de Crédito Bancário)
Instrumento jurídico que formaliza a operação de crédito. Contém:
- Valor principal (`principal_cents`)
- Deságio (`discount_cents`) — o custo financeiro da antecipação
- Taxa anual (`annual_rate`)
- Número de parcelas e data do primeiro vencimento

Uma CCB emitida gera automaticamente todas as `installments` numa única
transação de banco. O `discount_cents` é calculado na emissão e gravado —
nunca recalculado depois.

### Direito creditório
O "bem" abstrato que está sendo negociado: o direito de receber aquele dinheiro
futuro. Quando o cedente "cede" ao credor, transfere esse direito de forma
auditável no sistema.

### Conta vinculada (escrow)
Conta bancária com permissionamento especial para três partes. Diferente de
uma conta comum:
- Saídas acima do limite exigem aprovação do credor
- O saldo pertence ao cedente, mas o credor controla as saídas
- Toda movimentação é registrada no ledger imutável

Variante **Escrow Flex**: limites e regras podem ser alterados pelo credor
após a abertura (não implementado na v1, mas o `policy_rules` jsonb já suporta).

### Antecipação de recebíveis
A operação completa:
1. Cedente tem R$ 2M a receber em 12x
2. Credor paga R$ 1,8M agora (deságio de R$ 200k = custo financeiro)
3. Sacado paga as parcelas diretamente para a conta vinculada
4. Credor é o beneficiário final dos pagamentos

### Ledger de dupla entrada
Toda movimentação financeira gera um lançamento no `ledger_entry`.
**Nunca se atualiza um campo `saldo`** — o saldo é sempre calculado:

```sql
SELECT
  SUM(CASE WHEN direction = 'CREDIT' THEN amount_cents ELSE 0 END) -
  SUM(CASE WHEN direction = 'DEBIT'  THEN amount_cents ELSE 0 END)
FROM ledger_entry
WHERE account_id = $1 AND status = 'SETTLED';
```

Tipos de lançamento (`ledger_entry.type`):

| type                 | direction | quando ocorre                          |
|----------------------|-----------|----------------------------------------|
| `CREDIT_ANTECIPATION`| CREDIT    | credor deposita o valor antecipado     |
| `CREDIT_RECEIVED`    | CREDIT    | sacado paga uma parcela                |
| `DEBIT_RESERVED`     | DEBIT     | valor reservado antes de executar TED  |
| `DEBIT_EXECUTED`     | DEBIT     | TED liquidada com sucesso              |
| `DEBIT_REVERSED`     | DEBIT     | reserva desfeita após falha/rejeição   |

`DEBIT_RESERVED` + `DEBIT_EXECUTED` funcionam em par: reserva antes de enviar,
confirma depois. Se falhar, `DEBIT_REVERSED` desfaz. Nunca débita sem reservar.

### Conciliação
Job diário (02:00) que compara o que o ledger interno registrou com o que o
SPB mock reporta como efetivamente liquidado. Divergências geram:
- Registro na `reconciliation_run` com `divergences_found > 0`
- Evento `reconciliation.divergence_found` no RabbitMQ

### Inadimplência
Job diário (01:00) que marca parcelas vencidas:
- `status = 'OVERDUE'` quando `due_date < hoje` e `paid_cents < amount_cents`
- Juros de mora calculados sobre o saldo devedor (`amount_cents - paid_cents`)
- Evento `installment.overdue` publicado para cada parcela marcada

---

## Motor de aprovação (dupla alçada)

### O que é
Toda `payment_order` passa por um **policy engine** antes de ser executada.
O engine lê o `policy_rules` da conta e decide a ação:

| condição                          | ação                |
|-----------------------------------|---------------------|
| valor > `approval_required_above` | `PENDING_APPROVAL`  |
| horário fora da janela SPB        | `SCHEDULED`         |
| beneficiário nunca pago antes     | `PENDING_APPROVAL`  |
| limite diário atingido            | `REJECTED`          |
| nenhuma regra acionada            | `EXECUTE`           |

### policy_rules (jsonb na tabela account)
```json
{
  "approval_required_above_cents": 5000000,
  "blocked_hours": { "start": "17:00", "end": "09:00" },
  "new_beneficiary_requires_approval": true,
  "daily_limit_cents": 50000000,
  "approval_threshold": { "required": 2, "of": 3 }
}
```

### State machine da payment_order

```
DRAFT → POLICY_CHECK → PENDING_APPROVAL → APPROVED → EXECUTING → SETTLED
                    ↘                  ↘           ↘
                 SCHEDULED          REJECTED      FAILED → (compensação)
                                                           DEBIT_REVERSED
```

- `EXPIRED`: TTL de aprovação esgotado sem quorum → compensação automática
- Um único `REJECTED` de qualquer aprovador bloqueia a ordem
- Aprovação exige quorum N de M (ex: 2 de 3 diretores do credor)
- Cada aprovação gera uma linha na tabela `approval` (auditável)

### Idempotência
Antes de avaliar qualquer pagamento, o payment-service checa o `idempotency_key`
no Redis (TTL 24h). Se já existe, retorna o resultado anterior sem reprocessar.
O header obrigatório é `Idempotency-Key: <uuid>`.

---

## Cenários de borda importantes

### Pagamento parcial de parcela
Sacado paga R$ 600 de uma parcela de R$ 1.000:
- `paid_cents = 600`, `status = 'PARTIALLY_PAID'`
- Juros de mora calculados apenas sobre R$ 400 (saldo devedor)
- Parcela não é marcada como `PAID` até `paid_cents >= amount_cents`

### Pagamento a maior
Sacado paga R$ 1.100 numa parcela de R$ 1.000:
- Excedente de R$ 100 entra como `CREDIT_RECEIVED` na conta vinculada
- Evento `installment.overpaid` publicado para o credor decidir o destino
- Não é tratado automaticamente como receita

### TED que não liquida
SPB mock retorna erro após o `DEBIT_RESERVED`:
- payment-service publica `payment.failed` com `reservedEntryId`
- account-service consome e cria `DEBIT_REVERSED` para aquele entry
- `payment_order.status` vai para `FAILED` com `rejection_reason = 'spb_timeout'`

### Dois aprovadores simultâneos
Race condition no quorum N de M:
- Lock otimista na leitura do count de aprovações
- Query atômica: `COUNT(*) >= threshold` dentro de uma transação
- Último aprovador que completa o quorum dispara a execução
- Aprovações extras após o quorum são registradas mas ignoradas na execução

### Saque maior que o saldo
Antes de criar o `DEBIT_RESERVED`, o account-service verifica:
```
saldo_disponivel = balance - reservas_pendentes
```
Se `amount_cents > saldo_disponivel` → rejeita com `insufficient_balance`
antes de qualquer lançamento no ledger.

---

## Fluxo completo de uma operação (ponta a ponta)

```
1. Participantes criados (cedente, credor, sacado) + KYC aprovado
2. Conta vinculada aberta com policy_rules configuradas pelo credor
3. CCB emitida → installments geradas automaticamente
4. Credor deposita valor antecipado → CREDIT_ANTECIPATION no ledger
5. Sacado paga boletos mensais → CREDIT_RECEIVED por parcela
6. Cedente solicita TED de saída
7. Policy engine avalia → PENDING_APPROVAL (valor > limite)
8. Aprovadores do credor recebem email (Mailhog) com link
9. 2 de 3 aprovadores assinam → payment_order vai para APPROVED
10. SPB mock executa → DEBIT_RESERVED → DEBIT_EXECUTED
11. Evento payment.settled → ledger confirma + installment atualiza
12. Job 01:00 detecta inadimplência em parcelas vencidas
13. Job 02:00 concilia ledger com extrato SPB mock
```
