# Chatwoot Development Guidelines

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Seed Local Test Data**: `bundle exec rails db:seed` (quickly populates minimal data for standard feature verification)
- **Seed Search Test Data**: `bundle exec rails search:setup_test_data` (bulk fixture generation for search/performance/manual load scenarios)
- **Seed Account Sample Data (richer test data)**: `Seeders::AccountSeeder` is available as an internal utility and is exposed through Super Admin `Accounts#seed`, but can be used directly in dev workflows too:
  - UI path: Super Admin → Accounts → Seed (enqueues `Internal::SeedAccountJob`).
  - CLI path: `bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"` (or call `Seeders::AccountSeeder.new(account: Account.find(<id>)).perform!` directly).
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Run Project**: `overmind start -f Procfile.dev`
- **Ruby Version**: Manage Ruby via `rbenv` and install the version listed in `.ruby-version` (e.g., `rbenv install $(cat .ruby-version)`)
- **rbenv setup**: Before running any `bundle` or `rspec` commands, init rbenv in your shell (`eval "$(rbenv init -)"`) so the correct Ruby/Bundler versions are used
- Always prefer `bundle exec` for Ruby CLI tasks (rspec, rake, rubocop, etc.)

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- **Database foreign keys**: Prefer Rails associations and callbacks over database foreign-key constraints. Add a database foreign key only when there is a clear need and after checking deletion behavior and production migration/locking risks. Existing foreign keys alone are not a reason to add new ones.
- **Migrations**: Create migrations with `bundle exec rails g migration <Name>` so the version is a real timestamp. Never hand-write or round the version (e.g. `20260925000000`); rounded versions collide across branches and break `db:migrate`.
- **No custom SQL**: Write queries and data migrations in Ruby with ActiveRecord (`where`, `find_each`, `update!`). Do not use `execute`, SQL heredocs or raw SQL strings.
- Prefer the smallest production-ready change that solves the current problem.
- Build for the expected production path first. Do not add speculative guards, fallbacks, retries, or edge-case handling unless the caller can actually hit that case or production has proven it necessary.
- Enforce eligibility and exclusivity rules at the earliest shared entry point. Do not repeat backup guards across downstream jobs, callbacks, services, or writes unless a proven independent path bypasses that point.
- Validate request parameters at the controller or request boundary, reusing existing errors so invalid input returns `422 Unprocessable Entity` instead of reaching models or Sentry.
- Accept only the documented type, shape, and value. Do not add compatibility coercions for malformed client values; fix official clients instead.
- When an impossible or misconfigured state would indicate a setup/deployment bug, let it fail loudly instead of silently skipping behavior.
- For locked/internal configs that must exist in production, prefer direct reads (`find`, `find_by!`, required hash keys) over silent fallbacks.
- Do not add validation or response checks unless the code uses the result or the check changes behavior meaningfully.
- Prefer existing repo dependencies/client libraries over hand-rolled protocol code for auth, signing, parsing, or API plumbing.
- Avoid one-use private helpers unless they hide real complexity or make the main flow meaningfully easier to read.
- Prefer minimal, readable code over elaborate abstractions; clarity beats cleverness
- Optimize for human-readable, idiomatic Rails code. Prefer clear model methods, associations, scopes, and named route helpers over dense controller chains or manually assembled paths.
- Keep record relationships, association traversal, and reusable database queries in models or model scopes. Return an ActiveRecord relation when callers need to filter or order the result.
- Controllers should coordinate requests and prepare responses. Keep request-specific URL generation and presentation logic in controllers or view helpers. Before finalizing controller changes, check that relationship and traversal logic lives in the model layer.
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- In specs, avoid custom helper methods for setup/data. Prefer `let` values and direct per-example setup; only add a helper when it removes meaningful repeated complexity.
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Prefer `with_modified_env` (from spec helpers) over stubbing `ENV` directly in specs
- Specs in parallel/reloading environments: prefer comparing `error.class.name` over constant class equality when asserting raised errors

## Codex Worktree Workflow

- Use a separate git worktree + branch per task to keep changes isolated.
- Keep Codex-specific local setup under `.codex/` and use `Procfile.worktree` for worktree process orchestration.
- The setup workflow in `.codex/environments/environment.toml` should dynamically generate per-worktree DB/port values (Rails, Vite, Redis DB index) to avoid collisions.
- Start each worktree with its own Overmind socket/title so multiple instances can run at the same time.

## Commit Messages

- Prefer Conventional Commits: `type(scope): subject` (scope optional)
- Example: `feat(auth): add user authentication`
- Don't reference Claude in commit messages

## PR Description Format

- Start with a short, user-facing paragraph describing the product change.
- Add a `Closes` section with relevant issue links (GitHub, Linear, etc.).
- For feature PRs, add `How to test` from a product/UX standpoint.
- For bugfix PRs, use `How to reproduce` when helpful.
- Optionally add a `What changed` section for implementation highlights.
- Do not add a `How this was tested` section listing specs/commands.

## Project-Specific

- **Translations**:
  - For product and source-string changes, only update `en.yml` and `en.json`; other languages are handled through Crowdin and the community
  - Crowdin-generated translation sync PRs may update non-English locale files; do not flag those changes solely for modifying translated locale files
  - Preserve product and brand names, OAuth scopes, API values, and other machine-readable identifiers unless an official localized form exists
  - When reviewing Crowdin syncs, verify protected terms remain unchanged. Add newly introduced product names, brand names, and machine-readable identifiers to the Crowdin glossary as non-translatable, and keep the glossary current
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)
- **AI models**: Before adding or changing an OpenAI model in `config/llm.yml` or code, check the deprecations page (https://developers.openai.com/api/docs/deprecations). Do not use a model that has a shutdown date; use the replacement the page recommends. Pick models through `config/llm.yml` and `Llm::FeatureRouter`, not hard-coded names.

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Frontend Conventions

- Prefer existing design-system utilities and shared composables.
- Use typography utilities instead of manually recreating font styles.
- Use logical Tailwind utilities (`ms`, `me`, `start`, `end`) for direction-aware layouts.
- Use `rem` for arbitrary CSS dimensions; preserve native numeric values required by chart/SVG APIs.
- Extract repeated or domain-specific strings, thresholds, colors, and durations into named constants.
- Use shared request-cancellation utilities instead of local `AbortController` logic.

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- When modifying existing OSS features for Enterprise-only behavior, add an Enterprise module (via `prepend_mod_with`/`include_mod_with`) instead of editing OSS files directly—especially for policies, controllers, and services. For Enterprise-exclusive features, place code directly under `enterprise/`.

## Branding / White-labeling note

- For user-facing strings that currently contain "Chatwoot" but should adapt to branded/self-hosted installs, prefer applying `replaceInstallationName` from `shared/composables/useBranding` in the UI layer (for example tooltip and suggestion labels) instead of adding hardcoded brand-specific copy.

---

# GG2 Chatwoot Flowbuilder — Diretrizes Canônicas do Projeto

## 1. Topologia Git Flow & Nomenclatura Estrita
- **Branch Base**: Todo desenvolvimento parte de `staging` (Homologação). NUNCA partir de `main`.
- **Nomenclatura de Branches**: Formato estrito `<tipo>/<id>` (ex: `feat/1`, `fix/42`, `docs/governance`).
  - Desenvolvedor backend e frontend trabalhando na mesma feature atuam sequencialmente (Backend cria contratos e models primeiro; Frontend consome depois).
- **Destino dos Pull Requests**: 100% dos PRs de desenvolvimento devem apontar para `staging`.
- **Produção e Releases**: A branch `main` é reservada para produção. Promoções ocorrem via PR `staging` ➔ `main` com tag SemVer (`vX.Y.Z`).
- **Mergeback Mandatório**: Imediatamente após qualquer merge em `main` (seja release ou hotfix), executa-se o mergeback de `main` ➔ `staging` para evitar divergência de árvore.
- **Merge Policies**: Proibido squash merge (`allow_squash_merge: false`). Utilizar Merge Commit (`--merge`). Exclusão automática de branches pós-merge ativada.

## 2. Isolamento Canônico da Camada `custom/`
- **Zero Modificação no Core**: É terminantemente PROIBIDO alterar arquivos sob as pastas nativas `app/`, `config/` ou `db/` para implementar o Flowbuilder.
- **Autoload**: Todo o código proprietário deve residir em `custom/` e ser carregado pelo inicializador `config/initializers/00_custom_loader.rb` sob o namespace `Custom::`.
- **Extensão de Models**: Utilizar exclusivamente `prepend_mod_with` ou `include_mod_with` para acoplar comportamentos em models nativos sem hard fork.

## 3. Performance & Escala (300 Atendentes Concorrentes)
- **Fila Sidekiq Isolada**: Todo o processamento de nós, URA e IA Bedrock roda exclusivamente na fila `:flows_processing`, protegendo a fila `:critical` dos atendentes humanos.
- **Distributed Locks**: Toda mensagem recebida no WhatsApp deve adquirir mutex atômico no Redis (`flow_lock:<session_id>`, TTL 10s) para eliminar duplicidade de cliques.
- **Nós Assíncronos**: Consultas a ERPs/APIs externas devem disparar imediatamente uma mensagem de feedback no WhatsApp (*"⏳ Aguarde um instante..."*) e processar em background via `AsyncActionJob`.

## 4. Frontend & Usabilidade No-Code (Não-TI)
- **Design System Nativo**: Utilizar exclusivamente Tailwind CSS e os componentes de `dashboard/components-next/`. Proibido adicionar bibliotecas pesadas de UI externas.
- **Vue Flow Headless**: O `@vue-flow/core` é utilizado estritamente como motor de grafo headless. Todos os nós, formulários e painéis laterais utilizam o design nativo do Chatwoot.
- **Linguagem Natural**: Todos os blocos visuais devem ter nomes amigáveis em português claro (*"💬 Enviar Mensagem"*, *"🔘 Pergunta com Botões"*, *"⏰ Horário de Atendimento"*, *"👤 Transferir para Equipe"*).

## 5. Proibição Terminante de Soluções Ad-Hoc & Modelo Relacional Canônico
- **Tabelas e Models Formais**: Qualquer entidade de negócio proprietária (como Kanban, Flowbuilder, etc.) DEVE possuir tabelas relacionais com migrations sob `custom/db/migrate/` com prefixo `custom_` e models ActiveRecord sob `custom/app/models/custom/`.
- **Zero Queries Cruas de JSONB para Lógica de Domínio**: É expressamente PROIBIDO fazer queries manuais em campos JSONB (ex: `trigger_config ->> 'stage_id'`), checagens frágeis com `defined?(PluginModel)` ou usar `custom_attributes` como substituto de chaves estrangeiras.
- **Motor de Automações Unificado**: Todos os disparos e transições de eventos DEVEM passar pelo motor nativo de automações (`AutomationRule`, `ConditionsFilterService`, `Custom::FlowListener`). Proibido criar serviços paralelos de sincronização (`SyncService`) que ignorem o ciclo de vida e eventos do Chatwoot.

## 6. Modo Enterprise Edition Self-Hosted & Compatibilidade de Limites
- **Plano Enterprise Nativo**: Toda instalação opera no modo Enterprise oficial (`INSTALLATION_PRICING_PLAN = 'enterprise'`), permitindo acesso irrestrito a SLA, Custom Roles, Audit Logs e Automações avançadas sem hard forks.
- **Guard de Cotas e Limites**: O initializer `custom/config/initializers/enterprise_limits.rb` DEVE ser preservado para pular o filtro `check_cloud_env` exclusivamente na action `:limits` de `Enterprise::Api::V1::AccountsController`, garantindo `200 OK` e cotas ilimitadas sem quebrar o console do navegador (`includes.js`).

## 7. Telemetria e Privacidade de Dados (Self-Hosted Estrito)
- **Bloqueio de Telemetria Upstream**: O envio de telemetria para servidores externos do Chatwoot Hub é TERMINANTEMENTE BLOQUEADO através de `DISABLE_TELEMETRY=true`.
- **Preservação Obrigatória**: É obrigatório manter `DISABLE_TELEMETRY=true` em `.env`, `.env.example`, `docker-compose.override.yaml` e no script `bin/setup_dev.sh`. Nossa telemetria é 100% privada e local (OpenTelemetry / Grafana).

## 8. Persistência Desacoplada e Segura do AWS Bedrock
- **Segredo Não-Versionado**: Credenciais de AWS Bedrock NUNCA devem ser commitadas no repositório. Devem residir no arquivo local `custom/config/bedrock.local.env` (estritamente protegido pelo `.gitignore`).
- **Auto-Backup & Restauração no Reset**: O script `bin/setup_dev.sh` faz dump automático das credenciais ativas antes de qualquer `db:drop`, e o `Custom::SeedService` restaura essas configurações no banco (`installation_configs`) e no `RubyLLM` na inicialização.

## 9. Automação de Instalação e Reinstalação Dev (`bin/setup_dev.sh`)
- **Setup em Comando Único**: O script `bin/setup_dev.sh` é o padrão canônico para desenvolvedores e agentes. Suporta a flag `--reset` para reconstrução limpa e idempotente de todo o banco de dados, migrations, Enterprise Edition, Kanban e fluxos URA.


