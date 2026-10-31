# 08. Integração em Tempo Real com Chatwoot Kanban

## 1. Visão Geral

O módulo Kanban do Flowbuilder conecta a automação conversacional diretamente ao funil comercial e de SAC do Chatwoot (`chatwoot-kanban`), permitindo que a movimentação de clientes entre colunas ocorra de forma automática conforme as escolhas e interações na URA.

---

## 2. Nó `kanban_stage_change` (`Custom::Kanban::StageService`)

- **Localização**: `custom/app/services/custom/kanban/stage_service.rb`.
- **Invocação**: `Custom::Kanban::StageService.transition!(conversation, session, stage_id, stage_name)`.
- **Efeitos da Transição**:
  1. **Atributos Customizados da Conversa**:
     - `kanban_stage_id`: Identificador único do estágio no funil (ex: `lead_qualificado`, `aguardando_pagamento`, `proposta_enviada`).
     - `kanban_stage_name`: Nome legível do estágio para exibição visual.
     - `kanban_stage_updated_at`: Timestamp ISO8601 da última mudança.
  2. **Histórico de Estágios no Contexto JSONB**:
     - Registra em `session.context['stage_history']` a lista cronológica de estágios visitados pela conversa, viabilizando métricas de tempo de permanência (*dwell time*) e SLA do ciclo de vendas.
     - Atualiza `session.context['current_kanban_stage_id']`.

---

## 3. Broadcast em Tempo Real via ActionCable (Zero Polling)

- **Canal ActionCable**: `account_<account_id>_kanban`
- **Evento**: `kanban.stage_changed`
- **Payload**:
  ```json
  {
    "event": "kanban.stage_changed",
    "data": {
      "account_id": 1,
      "conversation_id": 1234,
      "stage_id": "lead_qualificado",
      "stage_name": "Lead Qualificado",
      "updated_at": "2026-10-31T12:00:00Z"
    }
  }
  ```
- **Comportamento no Frontend**:
  - Os clientes e atendentes com o painel Kanban aberto escutam o canal WebSocket da conta e movem o cartão instantaneamente de coluna, eliminando requisições periódicas via polling e reduzindo a carga do servidor.

---

## 4. Sincronização Bidirecional e Gatilhos de Entrada (`Custom::Kanban::SyncService`)

- **Objetivo**: Permitir que ações manuais ou automáticas nos cards do Kanban disparem ou retomem fluxos específicos.
- **Serviço Responsável**: `custom/app/services/custom/kanban/sync_service.rb`.
- **Invocação**: `Custom::Kanban::SyncService.handle_card_movement(conversation, new_stage_id, stage_name: nil)`.
- **Regras de Negócio**:
  1. Atualiza atributos customizados da conversa e emite evento WebSocket via `StageService`.
  2. Busca fluxos publicados (`status: :published`) associados ao estágio (`trigger_type: 'kanban_stage_entered'`, `trigger_config['stage_id']`).
  3. Caso encontre um fluxo compatível:
     - Encerra graciosamente qualquer sessão ativa anterior da conversa (`status: :completed`).
     - Instancia uma nova sessão (`Custom::FlowSession`) com o contexto `{ trigger: 'kanban_card_movement', stage_id: ... }`.
     - Inicia a execução do grafo pelo nó inicial via `Custom::Flows::ExecutionEngine.process!(session)`.


