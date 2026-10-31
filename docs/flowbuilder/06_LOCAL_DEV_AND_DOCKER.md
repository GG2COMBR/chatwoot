# 06. Ambiente Local Docker, Observabilidade & Seeds Neutras

## 1. Setup Local com Docker (`gg2-chatwoot`)

Para garantir isolamento total e paridade com a infraestrutura de produção em EC2, todos os serviços são agrupados sob o projeto Docker **`gg2-chatwoot`**:

```bash
# Sobe o banco Postgres com pgvector, Redis e Mailhog:
docker compose up -d postgres redis mailhog

# Sobe toda a aplicação conteinerizada:
docker compose up -d rails sidekiq vite
```

### Containers Ativos:
- `gg2-chatwoot-rails-1`: Porta `3000` (Puma Web)
- `gg2-chatwoot-sidekiq-1`: Background Workers
- `gg2-chatwoot-vite-1`: Porta `3036` (Hot-Reload)
- `gg2-chatwoot-postgres-1`: Porta `5432` (PostgreSQL 16 com extensão `vector`)
- `gg2-chatwoot-redis-1`: Porta `6379` (Redis 7)
- `gg2-chatwoot-mailhog-1`: Portas `1025` e `8025` (E-mails locais)

---

## 2. Stack de Observabilidade Local (`docker-compose.observability.yaml`)

Para testar métricas e dashboards de SRE localmente sem enviar dados para a nuvem:

```bash
docker compose -f docker-compose.yaml -f docker-compose.observability.yaml up -d prometheus grafana loki
```

- **Grafana**: `http://localhost:3001` (login: `admin` / `admin`)
- **Prometheus**: `http://localhost:9090` (raspa `/custom/metrics` a cada 5s)
- **Loki**: `http://localhost:3100` (ingere logs JSON em tempo real)

---

## 3. Seed Neutro GG2 (`custom:seed`)

Para popular um ambiente demonstrativo e funcional completo:

```bash
docker compose exec rails bundle exec rake custom:seed
```

### O que o Seed Cria:
1. Conta GG2 com plano Enterprise ativo.
2. Usuários de teste (Administrador, Supervisor, Agentes de Atendimento).
3. Caixa de Entrada WhatsApp Mock.
4. Equipes especializadas:
   - *Comercial & Vendas* (Seg-Sex 08h-18h, Sáb 08h-12h).
   - *SAC & Pós-Venda* (Seg-Sex 08h-18h).
   - *Grandes Contas / VIP* (Seg-Sáb 08h-20h).
5. Fluxos de exemplo completos:
   - *Template Funil de Vendas* (com catálogo e qualificação).
   - *Template Central de SAC* (com 2ª via, rastreio e CSAT).
