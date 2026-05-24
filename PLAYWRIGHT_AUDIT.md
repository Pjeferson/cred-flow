# Playwright E2E — Auditoria e Bugs Encontrados

> Documento temporário gerado durante auditoria real dos testes E2E.
> Data: 2026-05-24

---

## Resultado atual (último run com RAILS_ENV=test + globalSetup pendente)

| Teste | Status |
|---|---|
| Fluxo 1 — login com credenciais válidas redireciona para o dashboard | ✅ passa |
| Fluxo 1 — rota autenticada redireciona para /login sem token | ✅ passa |
| Fluxo 1 — credenciais inválidas exibem mensagem de erro | ⚠️ correção aplicada (BUG 2), não revalidado |
| Fluxo 2 — cria payment order e aparece em pending | ⚠️ correção aplicada (BUG 1), não revalidado |
| Fluxo 3 — tela de aprovações exibe ordens pendentes do seed | ✅ passa |
| Fluxo 3 — abre modal de revisão e registra aprovação | ⚠️ TASK-54 em andamento (BUG 3) |

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
**Arquivo:** `frontend/src/e2e/approvals.e2e.ts:41`

**Causa raiz confirmada:** os seeds de dev criam uma aprovação pré-existente para
`APPROVER_1_ID` em `seed-po-010`. O teste seleciona `index: 1` no `<select>`
(primeiro credor da lista vinda de account-service), que coincide com esse approver
já registrado → POST retorna 422 "Approver já registrou uma decisão" → modal não fecha.

Além disso, os seeds de dev têm `expires_at: 2h/4h` e o `ExpirePendingApprovalsJob`
roda a cada 5min, podendo expirar as ordens antes do teste.

**Solução em andamento: TASK-54 — banco de test isolado.**

---

## TASK-54 — Banco de test isolado para E2E (em andamento)

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

### Estado atual dos endpoints

- `POST http://localhost:3002/internal/e2e/seed` → ✅ **200 OK** (`pending_orders: 2, approvals: 0`)
- `POST http://localhost:3001/internal/e2e/seed` → ❌ **500** — container ainda rodando código em cache

### O que falta para concluir

1. **Reiniciar account-service** para carregar o novo controller:
   ```bash
   docker compose restart account-service
   ```
2. **Verificar** que `POST /internal/e2e/seed` retorna 200 em ambos os serviços
3. **Rodar o Playwright** com o override e confirmar que `globalSetup` executa sem erro
4. **Revalidar os 6 testes** esperando 5 ou 6 passando (BUG 1 e BUG 2 já corrigidos)

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
