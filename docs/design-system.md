# Design system — Ledgr

Interface para profissionais financeiros (gestores de FIDC, analistas de crédito).
O visual transmite precisão e confiança — não leveza de consumidor.
Referências de tom: Stripe Dashboard, Linear, Brex.

Stack de UI: shadcn/ui · Tailwind CSS · Recharts · TanStack Table · Tabler Icons

---

## Personalidade visual

- Clean e minimalista com **um único acento de cor forte** (índigo)
- Muito espaço em branco — dados sempre em primeiro plano
- Sofisticação pela densidade bem organizada, não pela ornamentação
- Sem gradientes decorativos, sem ilustrações, sem excesso de ícones
- Sem glassmorphism, sem sombras dramáticas

---

## Tokens

### Paleta — variáveis CSS

```css
:root {
  /* base */
  --color-bg:          #FFFFFF;
  --color-bg-subtle:   #F9FAFB;
  --color-bg-muted:    #F4F5F7;
  --color-border:      #E5E7EB;
  --color-border-strong: #D1D5DB;

  /* texto */
  --color-text-primary:   #111827;
  --color-text-secondary: #6B7280;
  --color-text-muted:     #9CA3AF;

  /* acento único */
  --color-indigo:          #4F46E5;
  --color-indigo-subtle:   #EEF2FF;
  --color-indigo-border:   #C7D2FE;

  /* semânticos */
  --color-success:         #16A34A;
  --color-success-subtle:  #DCFCE7;
  --color-warning:         #D97706;
  --color-warning-subtle:  #FEF3C7;
  --color-danger:          #DC2626;
  --color-danger-subtle:   #FEE2E2;

  /* radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
}
```

### Tipografia

```css
/* fonte base */
font-family: 'Inter', 'DM Sans', system-ui, sans-serif;

/* escala */
--text-xs:   11px;  /* labels uppercase, timestamps */
--text-sm:   12px;  /* labels, metadados */
--text-base: 13px;  /* corpo, itens de lista */
--text-md:   14px;  /* texto de card */
--text-lg:   15px;  /* títulos de página */
--text-xl:   22px;  /* valores monetários em destaque */
```

Regras fixas:
- Labels de campo: `11px · font-weight: 500 · uppercase · letter-spacing: 0.06em · color: --color-text-muted`
- Valores monetários: sempre `font-variant-numeric: tabular-nums` e tamanho maior que o contexto ao redor
- Títulos de seção: `font-weight: 500` — nunca 600 ou 700 em cards ou sidebar
- Corpo de tabela: `13px · font-weight: 400`

---

## Layout

### Estrutura base

```
┌─────────────────────────────────────────┐
│  sidebar (220px fixo)  │  main content  │
│  bg: --color-bg-subtle │  bg: --color-  │
│                        │  bg-muted      │
└─────────────────────────────────────────┘
```

```tsx
<div className="flex min-h-screen bg-[#F4F5F7]">
  <Sidebar />
  <main className="flex-1 flex flex-col overflow-hidden">
    <PageHeader />
    <div className="p-6 flex flex-col gap-4 overflow-auto">
      {children}
    </div>
  </main>
</div>
```

### Cards

```tsx
<div className="bg-white border border-[#E5E7EB] rounded-xl p-5">
  {/* nunca box-shadow estático — só no hover */}
  {/* hover:shadow-sm transition-shadow */}
</div>
```

### Métricas de topo (metric cards)

```tsx
<div className="bg-[#F4F5F7] rounded-lg p-4">
  <p className="text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF] mb-1.5">
    Saldo disponível
  </p>
  <p className="text-[22px] font-medium tabular-nums text-[#16A34A]">
    R$ 847.320
  </p>
  <p className="text-[11px] text-[#9CA3AF] mt-0.5">Atualizado agora</p>
</div>
```

Grid: `grid grid-cols-3 gap-2.5` — nunca mais que 4 métricas por linha.

---

## Componentes

### Sidebar

```tsx
<aside className="w-[220px] shrink-0 bg-[#F9FAFB] border-r border-[#E5E7EB] py-5 flex flex-col gap-0.5">

  {/* logo */}
  <div className="px-4 pb-5 border-b border-[#E5E7EB] mb-2">
    <span className="text-[15px] font-medium text-[#111827]">
      Ledgr
    </span>
  </div>

  {/* seção */}
  <p className="px-4 pt-4 pb-1 text-[11px] font-medium uppercase tracking-wider text-[#9CA3AF]">
    Operações
  </p>

  {/* item inativo */}
  <NavItem icon="ti-arrow-up-right" label="Pagamentos" />

  {/* item ativo */}
  <div className="flex items-center gap-2.5 px-4 py-[7px] text-[13px] font-medium
                  bg-[#EEF2FF] text-[#4F46E5] rounded-none cursor-pointer">
    <i className="ti ti-building-bank text-[16px]" />
    Conta vinculada
  </div>

  {/* item com badge de contagem */}
  <div className="flex items-center gap-2.5 px-4 py-[7px] text-[13px] text-[#6B7280] cursor-pointer
                  hover:bg-white hover:text-[#111827] transition-colors">
    <i className="ti ti-checks text-[16px]" />
    Aprovações
    <span className="ml-auto bg-[#FEF3C7] text-[#D97706] text-[10px] font-medium px-1.5 py-0.5 rounded">
      2
    </span>
  </div>

</aside>
```

### Status badges

Padrão: fundo com 10% de opacidade da cor semântica, texto na cor cheia.

```tsx
const badgeVariants = {
  settled:          'bg-[#DCFCE7] text-[#16A34A]',
  pending_approval: 'bg-[#FEF3C7] text-[#D97706]',
  rejected:         'bg-[#FEE2E2] text-[#DC2626]',
  failed:           'bg-[#FEE2E2] text-[#DC2626]',
  approved:         'bg-[#EEF2FF] text-[#4F46E5]',
  overdue:          'bg-[#FEE2E2] text-[#DC2626]',
  pending:          'bg-[#F4F5F7] text-[#6B7280]',
  executing:        'bg-[#EEF2FF] text-[#4F46E5]',
  scheduled:        'bg-[#FEF3C7] text-[#D97706]',
}

function StatusBadge({ status }: { status: keyof typeof badgeVariants }) {
  return (
    <span className={`inline-flex items-center text-[11px] font-medium px-2 py-0.5 rounded
                      ${badgeVariants[status]}`}>
      {status.replace('_', ' ')}
    </span>
  )
}
```

Nunca usar `outline` ou `ghost` variants do shadcn Badge para status financeiros —
sempre essas variantes customizadas com semântica explícita.

### Ledger timeline

Componente customizado — não tem equivalente em shadcn.

```tsx
const entryConfig = {
  CREDIT_RECEIVED:    { icon: 'ti-arrow-down-left', bg: '#DCFCE7', color: '#16A34A', sign: '+' },
  CREDIT_ANTECIPATION:{ icon: 'ti-bank',            bg: '#DCFCE7', color: '#16A34A', sign: '+' },
  DEBIT_EXECUTED:     { icon: 'ti-arrow-up-right',  bg: '#FEE2E2', color: '#DC2626', sign: '−' },
  DEBIT_RESERVED:     { icon: 'ti-lock',            bg: '#FEF3C7', color: '#D97706', sign: '−' },
  DEBIT_REVERSED:     { icon: 'ti-refresh',         bg: '#F4F5F7', color: '#6B7280', sign: '+' },
}

function LedgerItem({ entry }: { entry: LedgerEntry }) {
  const cfg = entryConfig[entry.type]
  return (
    <div className="flex items-center gap-2.5 py-2 border-b border-[#E5E7EB] last:border-0">
      <div className="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
           style={{ background: cfg.bg }}>
        <i className={`ti ${cfg.icon} text-[14px]`} style={{ color: cfg.color }} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[12px] font-medium text-[#111827] truncate">{entry.description}</p>
        <p className="text-[11px] text-[#9CA3AF]">{formatDate(entry.created_at)}</p>
      </div>
      <span className="text-[13px] font-medium tabular-nums whitespace-nowrap"
            style={{ color: cfg.color }}>
        {cfg.sign} {formatCurrency(entry.amount_cents)}
      </span>
    </div>
  )
}
```

### Fila de aprovação

Componente customizado.

```tsx
function ApprovalCard({ order }: { order: PaymentOrder }) {
  return (
    <div className="py-2.5 border-b border-[#E5E7EB] last:border-0 last:pb-0">

      {/* linha 1: nome + valor */}
      <div className="flex items-start justify-between mb-1.5">
        <div>
          <p className="text-[12px] font-medium text-[#111827]">{order.beneficiary_name}</p>
          <p className="text-[11px] text-[#9CA3AF]">
            {order.beneficiary_doc} · {policyReason(order.policy_action)}
          </p>
        </div>
        <span className="text-[14px] font-medium tabular-nums text-[#111827]">
          {formatCurrency(order.amount_cents)}
        </span>
      </div>

      {/* linha 2: quorum + TTL */}
      <div className="flex items-center justify-between">
        <p className="text-[11px] text-[#6B7280]">
          Aprovações:{' '}
          <span className="text-[#4F46E5] font-medium">
            {order.approvals_count} de {order.threshold_required}
          </span>
        </p>
        <p className="text-[11px] text-[#D97706] flex items-center gap-1">
          <i className="ti ti-clock text-[12px]" />
          Expira em {formatTTL(order.expires_at)}
        </p>
      </div>

      {/* ação primária sempre visível — nunca só no hover */}
      <button className="mt-2 bg-[#EEF2FF] text-[#4F46E5] border border-[#C7D2FE]
                         text-[11px] font-medium px-2.5 py-1 rounded-md hover:bg-[#E0E7FF]
                         transition-colors">
        Revisar e aprovar
      </button>
    </div>
  )
}
```

### Tabela de parcelas

Usar TanStack Table + shadcn Table. Linha `overdue` com fundo semântico.

```tsx
<TableRow
  className={cn(
    'text-[12px]',
    row.original.status === 'overdue' && 'bg-[#FEF2F2]'
  )}
>
  <TableCell className="text-[#6B7280] w-8">{row.original.number}</TableCell>
  <TableCell className="text-[#6B7280]">{formatDate(row.original.due_date)}</TableCell>
  <TableCell className="text-right tabular-nums font-medium">
    {formatCurrency(row.original.amount_cents)}
  </TableCell>
  <TableCell className="text-right tabular-nums font-medium"
             style={{ color: paidColor(row.original) }}>
    {row.original.paid_cents > 0 ? formatCurrency(row.original.paid_cents) : '—'}
  </TableCell>
  <TableCell className="text-right">
    <StatusBadge status={row.original.status} />
  </TableCell>
</TableRow>
```

### Botão primário

```tsx
<button className="bg-[#4F46E5] text-white text-[13px] font-medium
                   px-3.5 py-[7px] rounded-lg flex items-center gap-1.5
                   hover:bg-[#4338CA] active:scale-[0.98] transition-all">
  <i className="ti ti-arrow-up-right text-[14px]" />
  Nova transferência
</button>
```

Índigo só aqui e em links ativos. Em nenhum outro lugar.

---

## Utilitários

### Formatação monetária

```ts
export function formatCurrency(cents: number): string {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(cents / 100)
}
```

### Formatação de data

```ts
import { format, formatDistanceToNow } from 'date-fns'
import { ptBR } from 'date-fns/locale'

export function formatDate(iso: string): string {
  return format(new Date(iso), "d MMM, HH:mm", { locale: ptBR })
}

export function formatTTL(iso: string): string {
  return formatDistanceToNow(new Date(iso), { locale: ptBR })
}
```

### Motivo da política (policy_action → label)

```ts
const policyReasons: Record<string, string> = {
  amount_threshold:              'valor acima do limite',
  new_beneficiary:               'beneficiário novo',
  daily_limit_exceeded:          'limite diário atingido',
  outside_banking_hours:         'fora do horário SPB',
}

export function policyReason(action: string): string {
  return policyReasons[action] ?? action
}
```

---

## Decisões de biblioteca

### shadcn/ui — sim
Componentes copiados para o projeto, sem override de biblioteca. O design system
é nosso — shadcn é só a primitiva de acessibilidade (Radix UI por baixo).
Componentes usados: Table, Badge, Card, Dialog, Separator, ScrollArea, Tooltip.

### TanStack Table — sim
Para as tabelas com ordenação, paginação e row styling condicional.
shadcn tem um wrapper DataTable pronto que economiza configuração.

### Recharts — sim
Para o gráfico de fluxo de caixa projetado das parcelas.
API declarativa, cores configuráveis diretamente, sem brigar com tema.

### date-fns — sim
Formatação de datas e cálculo de TTL. Não usar dayjs ou moment.

### Tabler Icons — sim
`@tabler/icons-react` — outline only, mesma família do mockup.
```tsx
import { IconArrowUpRight } from '@tabler/icons-react'
<IconArrowUpRight size={16} />
```

### MUI — não
Personalidade visual própria forte demais. Override custoso.

### Ant Design — não
Mesmo motivo. Estética corporativa asiática que destoa do tom Stripe/Linear.

### Mantine — não
Mais flexível que MUI, mas adiciona peso desnecessário dado que shadcn já cobre.

### Tremor — não
Visual genérico para dashboards financeiros. Foge do tom definido.

---

## O que construir do zero

Esses componentes não têm equivalente pronto em shadcn e definem
a identidade visual do produto — vale o esforço:

| Componente | Por quê customizado |
|---|---|
| `LedgerItem` | Ícone direcional + cor semântica + valor tabular |
| `ApprovalCard` | Quorum N/M + TTL countdown + ação sempre visível |
| `StatusBadge` | Variantes financeiras com semântica explícita |
| `MetricCard` | Label uppercase + valor grande + subtexto |
| `PolicyBadge` | Tradução de `policy_action` para português |
