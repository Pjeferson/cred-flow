# CredFlow — Como funciona cada funcionalidade

---

## Atores do sistema

O sistema opera com três perfis de participante. No seed de desenvolvimento:

| Papel | Entidade | CNPJ |
|---|---|---|
| Cedente | Agro Norte Exportações S.A. | 12.345.678/0001-90 |
| Cedente | Construtora Horizonte Ltda | 23.456.789/0001-05 |
| Cedente | Tech Soluções Digitais ME | 34.567.890/0001-14 |
| Credor | FIDC Capital Nordeste | 45.678.901/0001-23 |
| Credor | FIDC Agro Investimentos | 56.789.012/0001-32 |
| Sacado | Distribuidora Alfa Ltda | 67.890.123/0001-41 |
| Sacado | Supermercados Beta S.A. | 78.901.234/0001-50 |
| Sacado | Atacado Gama Comércio Ltda | 89.012.345/0001-69 |

---

## 1. Participantes e KYC

**O que é:** cadastro das três partes que vão operar uma conta vinculada.

**Fluxo:** ao criar um participante, o sistema chama o kyc-mock com o CPF/CNPJ. O mock valida o formato e devolve `approved` ou `rejected`. Um participante com KYC rejeitado não pode ser vinculado a uma conta.

**Exemplo:** criar "Distribuidora Alfa Ltda" com CNPJ `67.890.123/0001-41` → kyc-mock aprova → participante fica com `kyc_status: approved`.

---

## 2. Conta vinculada (escrow)

**O que é:** uma conta com três partes e regras de governança. O saldo pertence ao cedente, mas o credor controla saídas acima do limite.

**Três contas no seed:**

| Conta | Cedente | Credor | Sacado | Limite para aprovação |
|---|---|---|---|---|
| ESC-0001 | Agro Norte | FIDC Capital Nordeste | Distribuidora Alfa | R$ 1.000,00 |
| ESC-0002 | Construtora Horizonte | FIDC Capital Nordeste | Supermercados Beta | R$ 2.000,00 |
| ESC-0003 | Tech Soluções | FIDC Agro Investimentos | Atacado Gama | R$ 500,00 |

**Saldo atual da ESC-0001 (calculado do ledger):**
- +R$ 12.000,00 (crédito recebido — antecipação FIDC)
- +R$ 8.000,00 (crédito recebido — segunda antecipação)
- −R$ 3.500,00 (TED executada)
- −R$ 1.500,00 (reserva pendente)
- **= R$ 15.000,00 disponível**

---

## 3. Ledger (extrato imutável)

**O que é:** toda movimentação da conta gera uma linha no ledger. Não existe campo `saldo` — o saldo é sempre calculado somando os lançamentos. Nenhum lançamento é deletado ou editado.

**Tipos de lançamento:**

| Tipo | Direção | Quando ocorre |
|---|---|---|
| `CREDIT_RECEIVED` | CRÉDITO | Sacado paga parcela / FIDC deposita antecipação |
| `DEBIT_RESERVED` | DÉBITO | Valor reservado antes de enviar TED |
| `DEBIT_EXECUTED` | DÉBITO | TED liquidada com sucesso no SPB |
| `DEBIT_REVERSED` | DÉBITO | Reserva desfeita após falha ou rejeição |

**Exemplo na ESC-0003:** uma TED de R$ 800 foi tentada, o SPB recusou → o sistema criou `DEBIT_REVERSED` com R$ 800 desfazendo a reserva. O saldo não foi afetado no líquido.

---

## 4. Motor de aprovação (dupla alçada)

**O que é:** toda solicitação de transferência passa por um policy engine que decide o que fazer antes de executar.

**Decisões possíveis:**

| Condição | Decisão |
|---|---|
| Valor ≤ limite da conta | Executa direto |
| Valor > limite da conta | Entra em fila de aprovação |
| Beneficiário novo (nunca pago antes) | Entra em fila de aprovação |
| Limite diário da conta atingido | Rejeita imediatamente |

**Exemplo com a ESC-0001 (limite R$ 1.000):**
- TED de R$ 750 para Distribuidora Alfa (já conhecida) → `execute` → liquida direto
- TED de R$ 2.500 para Distribuidora Alfa → `pending_approval` → aguarda 2 assinaturas do FIDC Capital Nordeste

**Estado atual no seed — fila de aprovação da ESC-0001:**
- `seed-po-010`: R$ 2.500,00 para Distribuidora Alfa → 1 aprovação registrada, aguarda a 2ª
- `seed-po-011`: R$ 1.800,00 para Supermercados Beta → 0 aprovações

**Exemplos de ordens encerradas:**
- `seed-po-020`: R$ 15.000,00 → `rejected` — limite diário da ESC-0003 excedido
- `seed-po-021`: R$ 2.200,00 → `expired` — prazo de aprovação esgotou sem quorum
- `seed-po-022`: R$ 350,00 → `failed` — SPB retornou timeout após execução

---

## 5. Ciclo de vida de uma payment order

```
DRAFT → POLICY_CHECK → PENDING_APPROVAL → APPROVED → EXECUTING → SETTLED
                    ↘                  ↘           ↘
                 SCHEDULED          REJECTED      FAILED
                                                    ↓
                                             DEBIT_REVERSED
                                           (ledger compensado)
```

**Idempotência:** toda ordem exige um `Idempotency-Key` único. Submeter a mesma chave duas vezes retorna o resultado original sem reprocessar — proteção contra double submit.

---

## 6. Recebíveis (CCB + parcelas)

**O que é:** a CCB formaliza a operação de crédito. Ao emitir uma CCB, o sistema gera todas as parcelas de uma vez na mesma transação de banco.

**Exemplo:**
- Cedente: Agro Norte (tem R$ 2M a receber em 12x do sacado)
- Credor: FIDC Capital Nordeste adianta R$ 1,8M agora (deságio de R$ 200k)
- CCB criada: principal R$ 2M, 12 parcelas mensais, taxa anual 18%
- Sistema gera 12 `installments` automaticamente com datas e valores calculados

**Ciclo das parcelas:**

| Status | Quando |
|---|---|
| `pending` | Parcela ainda não venceu |
| `partially_paid` | Sacado pagou menos do que o valor total |
| `paid` | `paid_cents >= amount_cents` |
| `overdue` | `due_date < hoje` e ainda não paga — detectado pelo job 01:00 |

**Pagamento a menor:** sacado paga R$ 600 de uma parcela de R$ 1.000 → `paid_cents = 600`, `status = partially_paid`. Juros de mora incidem só sobre os R$ 400 restantes.

---

## 7. Jobs automáticos

| Job | Horário | O que faz |
|---|---|---|
| `ExpirePendingApprovalsJob` | a cada 5 min | Marca como `expired` ordens que passaram do prazo sem quorum |
| `OverdueDetectionJob` | 01:00 diário | Marca parcelas vencidas como `overdue`, calcula mora |
| `ReconciliationJob` | 02:00 diário | Compara ledger interno com extrato do SPB mock; registra divergências |

---

## 8. Fluxo completo ponta a ponta

```
1. Criar participantes (cedente + credor + sacado) — KYC aprovado pelo mock

2. Abrir conta vinculada — credor define as policy_rules
   (limite para aprovação, quorum, limite diário)

3. Emitir CCB — gera 12 parcelas automaticamente
   Credor deposita o valor antecipado → CREDIT_ANTECIPATION no ledger

4. Sacado paga boleto mensal → CREDIT_RECEIVED no ledger
   Evento payment.settled → installment atualizada para paid

5. Cedente solicita TED de saída via "Nova transferência"
   Policy engine avalia:
     - R$ 800 para beneficiário já pago → executa direto
     - R$ 5.000 acima do limite → entra em pending_approval

6. Aprovadores do FIDC recebem email (Mailhog localhost:8025)
   2 de 3 assinam na tela Aprovações → APPROVED
   SPB mock executa → DEBIT_RESERVED → DEBIT_EXECUTED

7. Se SPB falhar → payment.failed → DEBIT_REVERSED compensa o ledger
   Se ninguém aprovar no prazo → expired → compensação automática

8. Job 02:00 concilia: compara ledger × extrato SPB
   Divergência → reconciliation_run com status divergent
```
