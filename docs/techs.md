# CredFlow — Tecnologias utilizadas

Mapeamento completo de linguagens, frameworks e bibliotecas do projeto, com descrição de como cada uma é usada.

---

## Backend

### Ruby 3.4
Linguagem principal dos três serviços e dos três mocks. Escolha pelo ecossistema maduro para APIs financeiras (Rails, Dry::Monads, AASM) e pela produtividade em DSLs expressivas.

### Ruby on Rails 8.1 (API-only)
Framework base dos três serviços (`account-service`, `payment-service`, `receivables-service`). Usado no modo `--api`, sem views, sem assets — apenas controllers, models, serializers e middleware. O Rails 8 traz o Solid Queue embutido, eliminando a necessidade de Sidekiq/Redis para jobs.

**Como está configurado:**
- Cada serviço é uma aplicação Rails independente com seu próprio banco
- Rotas prefixadas com `/api/v1/`
- Resposta sempre em JSON via `jsonapi-serializer`
- CORS configurado via `rack-cors` para aceitar requisições do frontend em `localhost:5173`

### PostgreSQL 17
Banco relacional de cada serviço. Três instâncias isoladas: `postgres-account` (5432), `postgres-payment` (5433), `postgres-receivables` (5434). Nenhum serviço faz JOIN cross-database.

**Destaques de uso:**
- `ledger_entries`: append-only por convenção (sem UPDATE/DELETE)
- `policy_rules` em `accounts`: coluna JSONB armazenando regras de aprovação flexíveis
- `installments`: index parcial em `(due_date) WHERE status IN ('pending', 'partially_paid')` para o job de inadimplência
- Valores monetários sempre em `bigint` (centavos), nunca `float`

### Devise + devise-jwt
Autenticação no `account-service`. O Devise gerencia cadastro, login e logout. O devise-jwt emite e revoga tokens JWT via `JwtDenylist` (tabela de tokens revogados no banco).

**Como está configurado:**
- `payment-service` e `receivables-service` não usam Devise — verificam o JWT manualmente com a gem `jwt`, usando o mesmo `DEVISE_JWT_SECRET_KEY` compartilhado via variável de ambiente
- O hook de 401 no frontend redireciona para `/login` em qualquer resposta não autenticada, exceto nos endpoints `/auth/` (para não suprimir mensagens de erro de login)

### AASM (Acts As State Machine)
Máquina de estados para `PaymentOrder` no `payment-service`. Define os estados (`draft`, `policy_check`, `pending_approval`, `approved`, `executing`, `settled`, `rejected`, `failed`, `expired`) e as transições válidas entre eles com callbacks.

**Por que AASM:** garante que transições inválidas (ex: `settled` → `draft`) sejam bloqueadas em nível de model, não apenas no controller.

### Dry::Monads
Padrão `Result` (Success/Failure) para service objects nos três serviços. Todo service object retorna `Success(payload)` ou `Failure(reason)`, forçando o caller a tratar ambos os casos sem exceções de controle de fluxo.

**Exemplo de uso:** `PolicyEngineService` retorna `Success(:execute)`, `Success(:pending_approval)` ou `Failure(:daily_limit_exceeded)`. O controller faz pattern match no resultado para decidir o status HTTP.

### Pundit
Autorização por recurso. Políticas em `app/policies/`, uma por model. No estado atual do portfólio, todos os usuários têm acesso pleno (sem RBAC implementado); Pundit está no lugar como estrutura para a evolução futura (ver ENT-01 no backlog).

### jsonapi-serializer
Serialização de respostas no padrão JSON:API (`{ data: { id, type, attributes } }`). Serializers em `app/serializers/`. O frontend usa a chave `data.attributes` para extrair os campos.

### Bunny
Cliente AMQP para publicação de eventos no RabbitMQ. Usado pelo `EventPublisher` nos três serviços para publicar no exchange `credflow.events` (topic). Envelope padrão com `eventId`, `eventType`, `occurredAt`, `correlationId` e `payload`.

### Sneakers
Framework de consumers RabbitMQ para Rails, baseado em threads. Roda como processo separado (não no Puma). Em desenvolvimento, iniciado manualmente via `bundle exec sneakers work NomeDoConsumer`. Consumers herdam de `ApplicationConsumer`, que implementa retry exponencial (3 tentativas, backoff 1s/2s/4s) e dead-letter após esgotar as tentativas.

### Solid Queue
Backend de jobs assíncronos e cron do Rails 8. Persiste filas no banco PostgreSQL do próprio serviço (sem Redis extra). Configurado para subir junto com o Puma via `Procfile.dev`.

**Jobs agendados (`config/recurring.yml`):**
- `ExpirePendingApprovalsJob` — payment-service, a cada 5 min
- `OverdueDetectionJob` — receivables-service, 01:00 diário
- `ReconciliationJob` — receivables-service, 02:00 diário

### Redis 7
Usado em dois contextos distintos:
- **Idempotência de payment orders** (payment-service): guarda o resultado de cada `Idempotency-Key` por 24h; requisições repetidas retornam o resultado cacheado sem reprocessar
- **Cache de eventos** (account-service, receivables-service): evita reprocessamento de eventos RabbitMQ duplicados

### Faraday
HTTP client para chamadas síncronas entre serviços e para os mocks externos. Usado em `AccountServiceClient` (payment e receivables → account-service), chamadas ao `kyc-mock`, `spb-mock` e `boleto-mock`, e na consulta ao RabbitMQ Management API no `MonitoringController`.

### rack-cors
Middleware CORS nos três serviços Rails. Configurado para aceitar qualquer origem em desenvolvimento (necessário para o frontend em `localhost:5173` chamar a API em `localhost:8080`).

### Sinatra (mocks)
Framework minimalista Ruby para os três mocks externos:
- **kyc-mock** (4002): valida formato de CPF/CNPJ e retorna `approved`/`rejected`
- **spb-mock** (4001): simula liquidação TED/Pix; pode retornar `settled` ou erro controlado
- **boleto-mock** (4003): gera linha digitável matematicamente válida

### RSpec + FactoryBot + Faker + Shoulda Matchers
Stack de testes de backend. Request specs em `spec/requests/` cobrem o contrato HTTP de cada endpoint. FactoryBot cria fixtures de test sem duplicar setup. Faker gera dados realistas (CPF, CNPJ, nomes). Shoulda Matchers adiciona matchers declarativos para validações de model.

### Brakeman + Bundler Audit + RuboCop
Ferramentas de qualidade: Brakeman analisa vulnerabilidades estáticas no código Rails; Bundler Audit verifica gems com CVEs conhecidas; RuboCop (com preset `rubocop-rails-omakase`) enforça estilo.

---

## Frontend

### React 19
Biblioteca de UI. Uso de componentes funcionais com hooks. O React 19 traz melhorias de performance no reconciliation e suporte nativo a `use()` para Promises, mas o projeto usa principalmente o modelo hooks convencional (useState, useEffect, custom hooks).

### TypeScript 6
Tipagem estática em todo o frontend. Tipos definidos inline ou em `types.ts` dentro de cada feature. Interfaces para payloads de API, estados de formulário e props de componentes.

### Vite 8
Bundler e dev server. Hot Module Replacement instantâneo. Build de produção com tree-shaking e code splitting automático. Configurado com o plugin `@tanstack/router-plugin` para geração automática do arquivo de rotas tipado.

### TanStack Router 1.x
Roteamento client-side com tipagem 100% TypeScript. Usa **file-based routing**: a estrutura de arquivos em `src/routes/` define as rotas automaticamente. Padrão de layout via `<Outlet />` — um arquivo `foo.tsx` é layout pai de todos os arquivos dentro de `foo/`.

**Como está configurado:**
- `_authenticated.tsx` — layout que verifica JWT e redireciona para `/login` se não autenticado
- `ccbs.tsx` + `ccbs/index.tsx` — layout e lista de CCBs
- `ccbs/$ccbId.tsx` + `ccbs/$ccbId/index.tsx` — layout e detalhe de CCB com parcelas
- `accounts/$accountId.tsx` + `accounts/$accountId/index.tsx` — layout e detalhe de conta

### TanStack Query 5.x
Cache e sincronização de estado servidor. Toda chamada de API passa por `useQuery` (leitura) ou `useMutation` (escrita). Gerencia loading, error, stale e refetch automaticamente.

**Como está configurado:**
- `queryKey` hierárquico: `["accounts"]`, `["accounts", id]`, `["accounts", id, "ledger_entries"]`
- `onSuccess` de mutations invalida queries relacionadas para forçar refetch (ex: criar payment order invalida `ledger_entries` e `balance` da conta)
- `refetchInterval: 30_000` no painel de monitoramento para atualização automática

### Zustand 5
Estado global de UI. Usado exclusivamente para o estado de autenticação (`authStore`): usuário logado, flag `isAuthenticated` e função `logout`.

**Como está configurado:**
- Middleware `persist` armazena `user` e `isAuthenticated` no localStorage (`credflow_auth`), sobrevivendo a reloads
- `partialize` seleciona apenas os campos que devem ser persistidos (evita armazenar funções)
- Estado de servidor (listas, detalhes, saldos) fica no TanStack Query — nunca duplicado no Zustand

### ky 1.x
HTTP client baseado em `fetch`. Substitui Axios com API mais moderna (Promises nativas, sem dependências). Configurado em `src/lib/api.ts` com:
- Base URL apontando para o API Gateway (`http://localhost:8080`)
- Hook `beforeRequest` que injeta o JWT do localStorage no header `Authorization`
- Hook `afterResponse` que redireciona para `/login` em 401 (exceto endpoints `/auth/`)

### shadcn/ui
Coleção de componentes React copiados para `src/components/ui/` (não instalados como dependência — o código fica no projeto). Construídos sobre Radix UI (acessibilidade) e estilizados com Tailwind. Componentes usados: `Button`, `Dialog`, `Select`, `Input`, `Badge`, `Table`, entre outros.

**Como está configurado:** componentes importados de `@/components/ui/` via alias de path configurado no `tsconfig.json`.

### Tailwind CSS 4
Framework CSS utility-first. Versão 4 usa o novo engine baseado em PostCSS com configuração via CSS (`@import "tailwindcss"`) ao invés de `tailwind.config.js`. Classes aplicadas diretamente nos JSX sem arquivos CSS separados.

**Detalhe de uso no projeto:** design system consistente com paleta restrita — `#4F46E5` (indigo, ações primárias), `#111827` (texto principal), `#6B7280` (texto secundário), `#E5E7EB` (bordas), `#F9FAFB` (backgrounds). Utilitários de layout: `flex`, `grid`, `gap`, `px`, `py`. Estados interativos: `hover:`, `active:`, `disabled:`.

### Tabler Icons React 3.x
Biblioteca de ícones SVG como componentes React. Usados no sidebar (`IconBuildingBank`, `IconChecks`, `IconFileText`, `IconActivity`, `IconUsers`, `IconLogout`), em botões e em células de tabela. Ícones inline com `size` prop em pixels.

### date-fns 4.x
Utilitário de formatação e manipulação de datas. Funções usadas: `format` (formata datas para exibição), `parseISO` (converte strings ISO para objetos Date). Centralizado em `src/lib/formatters.ts` (`formatDate`, `formatDateOnly`, `formatDateShort`).

### clsx + tailwind-merge + class-variance-authority
Utilitários para composição condicional de classes CSS:
- `clsx`: concatena classes condicionalmente (`clsx("base", condition && "extra")`)
- `tailwind-merge`: resolve conflitos de classes Tailwind (ex: `px-2 px-4` → `px-4`)
- `class-variance-authority` (CVA): cria variantes tipadas de componentes (usado nos componentes shadcn/ui)

---

## Testes de Frontend

### Vitest 3.x
Test runner compatível com Vite. Usa a mesma configuração de build do projeto (aliases, TypeScript, plugins). API compatível com Jest (`describe`, `it`, `expect`). Roda em modo watch durante desenvolvimento e em modo `--run` no CI.

### Testing Library (React + User Event + Jest DOM)
Testa componentes pela perspectiva do usuário: busca elementos por texto, label, role — não por seletores CSS ou refs internos. `userEvent` simula digitação, cliques e submits de forma realista (com propagação de eventos). `jest-dom` adiciona matchers como `toBeInTheDocument()`, `toHaveValue()`, `toBeDisabled()`.

### MSW 2.x (Mock Service Worker)
Intercepta chamadas HTTP em nível de Service Worker (browser) ou Node (testes). Nos testes Vitest, usa o modo Node com `setupServer`. Handlers definidos por teste simulam respostas da API sem precisar da stack Rails no ar.

**Diferencial:** ao contrário de mocks de módulo, o MSW intercepta na camada de rede — o código de produção (`api.ts`, hooks TanStack Query) roda sem alteração nos testes.

### jsdom 29
Simula o DOM do browser em ambiente Node para os testes Vitest. Configurado via `vitest.config.ts` com `environment: "jsdom"`. Permite renderizar componentes React e interagir com o DOM em testes unitários sem abrir um browser.

### Playwright 1.60
Testes E2E (end-to-end) contra o browser real (Chromium por padrão). Fluxos cobertos: login → dashboard, criar payment order, aprovar ordem. `globalSetup` semeia o banco de test via HTTP antes da suíte. Configurado para rodar contra `http://localhost:5173` com a stack completa no ar via Docker Compose.

---

## Infraestrutura

### Docker Compose
Orquestração local de todos os serviços. Um único `docker-compose.yml` sobe 15+ containers: 3 Rails, 3 PostgreSQL, Redis, RabbitMQ, 3 mocks Sinatra, frontend Vite, Nginx e Mailhog. `docker-compose.e2e.yml` sobrescreve `RAILS_ENV=test` nos serviços Rails para os testes E2E sem tocar o banco de desenvolvimento.

### Nginx (API Gateway)
Proxy reverso que centraliza todas as chamadas do frontend. Roteia por prefixo de URL:
- `/api/v1/(auth|participants|accounts|ledger)` → account-service:3000
- `/api/v1/(payment_orders|approvals)` → payment-service:3000
- `/api/v1/(ccbs|installments|reconciliation|monitoring)` → receivables-service:3000

Elimina a necessidade de o frontend conhecer portas individuais dos serviços.

### RabbitMQ 3 (Management Plugin)
Broker de mensagens para comunicação assíncrona entre serviços. Exchange `credflow.events` (topic) recebe todos os eventos. Exchange `credflow.dlx` é o dead-letter exchange — mensagens que falharam após 3 retries chegam aqui. O Management API (porta 15672) é consultado pelo `MonitoringController` para exibir status da fila DLQ no painel.

### Mailhog
SMTP fake que captura todos os emails enviados em desenvolvimento. Interface web em `localhost:8025`. Usado para inspecionar emails de aprovação solicitada e notificação de pagamento falho sem configurar um provedor real.
