# Playwright E2E — Auditoria e Bugs Encontrados

> Documento temporário gerado durante auditoria real dos testes E2E.
> Data: 2026-05-24

---

## Resultado final — 6/6 passando (TASK-54 concluída)

| Teste | Status |
|---|---|
| Fluxo 1 — login com credenciais válidas redireciona para o dashboard | ✅ passa |
| Fluxo 1 — rota autenticada redireciona para /login sem token | ✅ passa |
| Fluxo 1 — credenciais inválidas exibem mensagem de erro | ✅ passa (BUG 2 corrigido) |
| Fluxo 2 — cria payment order e aparece em pending | ✅ passa (BUG 1 + seletores corrigidos) |
| Fluxo 3 — tela de aprovações exibe ordens pendentes do seed | ✅ passa |
| Fluxo 3 — abre modal de revisão e registra aprovação | ✅ passa (BUG 3 + BUG 4 corrigidos) |

---

## Bugs de configuração (já corrigidos)

### C1 — `testMatch` ausente no `playwright.config.ts`
Os arquivos `.e2e.ts` não eram detectados pelo Playwright porque o padrão padrão dele
procura por `*.spec.ts` e `*.test.ts`. Sem o `testMatch`, os 6 testes nunca eram
encontrados (0 testes em 0 arquivos).

**Correção aplicada:** adicionado `testMatch: "**/*.e2e.ts"` em `playwright.config.ts`.

### C2 — Versão da imagem Docker desatualizada
O `docker-compose.yml` usava `mcr.microsoft.com/playwright:v1.52.0-noble` mas o
`package.json` já tinha `@playwright/test: ^1.60.0`. O Chromium embutido na imagem
v1.52 não existia no path esperado pela versão 1.60 da biblioteca.

**Correção aplicada:** imagem atualizada para `v1.60.0-noble`.

### C3 — Nginx com IPs cacheados após restart dos Rails services
Após reiniciar os serviços Rails (por causa de PID file stale), o Nginx continuou
roteando `/api/v1/auth/*` para o payment-service (que herdou o IP antigo do
account-service). Resultado: 404 "No route matches" vindo do serviço errado.

**Correção:** `docker compose restart api-gateway` força re-resolução dos IPs.
Causa raiz permanece: o Nginx resolve upstreams apenas na inicialização.

---

## Bugs de aplicação/teste a corrigir

### BUG 1 — Seletor de link errado no teste de payment order
**Arquivo:** `frontend/src/e2e/payment-order.e2e.ts:17`

```ts
// teste procura por:
await page.getByRole("link", { name: /contas/i }).click();

// label real no Sidebar.tsx:
label="Conta vinculada"
```

`/contas/i` procura a substring "contas" que não existe em "Conta vinculada".
O teste nunca encontra o link e estoura timeout de 30s.

**Correção:** mudar o seletor para `/conta vinculada/i`.

---

### BUG 2 — Hook de 401 no `api.ts` impede exibição de erro de login
**Arquivo:** `frontend/src/lib/api.ts`

```ts
afterResponse: [
  async (_request, _options, response) => {
    if (response.status === 401) {
      clearToken();
      window.location.href = "/login"; // ← redireciona SEMPRE em 401
    }
    return response;
  },
],
```

Quando o usuário digita email/senha errados, a API retorna 401. O hook intercepta
esse 401 e faz um hard redirect para `/login`. A página recarrega do zero, o estado
da mutation TanStack Query é perdido, e `signIn.error` volta a ser `null`.
O texto "Email ou senha inválidos" nunca é renderizado.

**Correção:** não redirecionar para /login quando a URL da requisição for o próprio
endpoint de autenticação (`/auth/sign_in` ou `/auth/sign_up`).

```ts
if (response.status === 401 && !request.url.includes("/auth/")) {
  clearToken();
  window.location.href = "/login";
}
```

---

### BUG 3 — Modal de aprovação não fecha após Confirmar
**Arquivos:** `services/payment-service/app/services/process_approval_service.rb`,
`services/account-service/app/controllers/internal/e2e_controller.rb`

**Causa raiz real:** `ProcessApprovalService#fetch_policy_rules` retorna um hash
com chaves símbolo (porque `AccountServiceClient` usa `symbolize_names: true`), mas
a linha seguinte usava `.dig("approval_threshold")` com chave STRING. Isso retorna
`nil`, forçando `required = 1`. Com quorum de 1, a primeira aprovação disparava
`ExecutePaymentService` → erro no SPB mock → mutation lança exceção → modal fica aberto.

**Correção aplicada:**
```ruby
# antes:
threshold_cfg = (policy_rules.dig("approval_threshold") || {}).symbolize_keys
# depois:
threshold_cfg = policy_rules.dig(:approval_threshold) || {}
```

**Seed também corrigido:** `approval_threshold: { required: 2, of: 3 }` adicionado
ao `policy_rules` na semente E2E do account-service.

---

## TASK-54 — Banco de test isolado para E2E (✅ concluída)

**Objetivo:** E2E roda contra `RAILS_ENV=test` (bancos `_test`), nunca toca bancos de dev.
O `globalSetup` do Playwright semeia dados controlados antes de cada suíte.

### Arquivos criados/modificados

| Arquivo | Status |
|---|---|
| `docker-compose.e2e.yml` | ✅ criado |
| `services/account-service/lib/tasks/seed_e2e.rake` | ✅ criado |
| `services/payment-service/lib/tasks/seed_e2e.rake` | ✅ criado |
| `services/account-service/app/controllers/internal/e2e_controller.rb` | ✅ criado |
| `services/payment-service/app/controllers/internal/base_controller.rb` | ✅ criado |
| `services/payment-service/app/controllers/internal/e2e_controller.rb` | ✅ criado |
| `services/account-service/config/routes.rb` | ✅ rota `POST /internal/e2e/seed` adicionada |
| `services/payment-service/config/routes.rb` | ✅ namespace `internal` + rota `POST /internal/e2e/seed` |
| `frontend/src/e2e/global-setup.ts` | ✅ criado |
| `frontend/playwright.config.ts` | ✅ `globalSetup` adicionado |
| `CLAUDE.md` | ✅ comandos E2E atualizados |

### Resultado

```
6 passed (3.7s)
```

---

## Aprendizados sobre execução dos testes

### 1. "Testes existem" ≠ "Testes rodam"
Os 48 testes que passavam no `npm run test` eram 100% Vitest (unitários + componente).
Os 6 testes E2E do Playwright nunca foram executados. `npm run test` não chama
`playwright test` — são scripts distintos: `test` e `test:e2e`.

### 2. Dois bugs de configuração ocultavam os testes completamente
Sem `testMatch`, o Playwright reportava "0 tests found" e saía sem erro de runtime.
Sem a versão correta da imagem, todos os 6 testes falhavam antes de abrir o browser.
Ambos os bugs foram introduzidos na implementação da TASK-53 sem validação.

### 3. Testes E2E exigem estado de infraestrutura estável
O Nginx cacheou IPs de containers reiniciados, roteando requisições para o serviço
errado. Isso seria um falso negativo em qualquer CI que reiniciasse serviços
durante a execução. A solução definitiva é adicionar `resolver` dinâmico no Nginx
ou usar `depends_on` com healthcheck que force o gateway a reiniciar após os Rails.

### 4. Os testes E2E que passam são genuinamente E2E
Os 3 testes que passam (login com sucesso, redirect sem token, lista de aprovações)
tocam o browser real, fazem requisições HTTP reais para o stack Docker e verificam
comportamento observável na UI. Não há mocks.

### 5. Os bugs encontrados são bugs reais da aplicação
O BUG 2 (redirect em 401 durante login) é um bug funcional que existiria em produção:
tentar logar com senha errada causa reload da página em vez de exibir mensagem de erro.
Só foi descoberto porque os testes E2E foram de fato executados.
