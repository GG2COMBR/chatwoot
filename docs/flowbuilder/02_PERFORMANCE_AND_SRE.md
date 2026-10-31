# 02. Performance, Escala para 300 Atendentes e Observabilidade SRE

## 1. Desafio de Escala: 300 Atendentes Concorrentes

Um dos requisitos centrais do projeto é suportar **300+ atendentes humanos simultâneos** trabalhando no painel web enquanto milhares de clientes finais navegam na URA interativa no WhatsApp.

Para evitar que mensagens da URA afetem a latência dos atendentes:

### A. Fila Sidekiq Isolada (`:flows_processing`)
- O processamento de nós, chamadas a APIs e geração de respostas de IA **NUNCA** rodam na fila `:critical` ou `:default` do Chatwoot.
- Criamos a fila dedicada `:flows_processing`.
- A injeção da fila é feita dinamicamente via `custom/config/initializers/sidekiq.rb` sem editar `config/sidekiq.yml`.
- Se a URA sofrer uma avalanche de 10.000 mensagens simultâneas, os atendentes humanos continuam recebendo e enviando mensagens em tempo real com zero delay.

### B. Distributed Mutex no Redis (Controle de Concorrência)
- Clientes de WhatsApp costumam enviar mensagens repetidas ou clicar rapidamente em vários botões.
- A cada mensagem recebida, o processamento de nós adquire um **Distributed Lock no Redis** através de `Custom::Flows::LockService`:
  ```ruby
  Custom::Flows::LockService.with_lock("session:#{session_id}", ttl_ms: 10_000) do
    # Execução atômica e segura
  end
  ```
- **Liberação Atômica Segura**: Utiliza script Lua atômico para garantir que somente o detentor do lock possa liberá-lo, prevenindo liberação acidental em caso de expiração por timeout.
- Se uma mensagem simultânea chegar enquanto a anterior está sendo processada, o lock descarta a duplicidade ou aborta a execução duplicada graciosamente, eliminando mensagens repetidas no WhatsApp.

### C. Job Assíncrono Isolado (`Custom::Flows::ProcessFlowJob`)
- Localizado em `custom/app/jobs/custom/flows/process_flow_job.rb`.
- Mapeado estritamente para `queue_as :flows_processing`.
- Executa dentro do bloco `Custom::Flows::LockService.with_lock`, garantindo integridade de sessão concorrente.

---

## 2. A Stack de SRE & Observabilidade Privada

Toda a telemetria é direcionada para serviços internos sob controle da empresa:

### A. Logs Estruturados JSON (Lograge + Correlation ID)
- Variáveis no `.env`:
  ```bash
  LOGRAGE_ENABLED=true
  RAILS_LOG_TO_STDOUT=true
  ```
- Cada passo da URA emite log estruturado com:
  - `flow_id`, `session_id`, `node_id`, `node_type`, `execution_time_ms`, `status`.

### B. Métricas de SRE para Prometheus / Grafana (`/custom/metrics`)
- `chatwoot_flow_execution_duration_seconds`: Histograma de latência por tipo de nó.
- `chatwoot_sidekiq_queue_latency_seconds`: Alerta de SRE se a fila `:flows_processing` demorar mais de 5s.
- `chatwoot_bedrock_duration_seconds` e `chatwoot_bedrock_tokens_total`: Consumo e tempo da IA.

### C. Healthcheck Aprofundado (`/custom/health`)
- Valida ativamente a conectividade e latência de:
  - **PostgreSQL**: Executa `SELECT 1`.
  - **Redis**: Executa `Redis::Alfred.ping`.
  - **Sidekiq**: Confere se há processos ativos consumindo as filas.
- Retorna `200 OK` (saudável) ou `503 Service Unavailable` (se houver queda de banco ou cache).

### D. Rastreamento Global de Erros (Sentry)
- Ao configurar `SENTRY_DSN`, todas as exceções não tratadas da aplicação e dos jobs são enviadas com tags de contexto (`flow_id`, `conversation_id`).
