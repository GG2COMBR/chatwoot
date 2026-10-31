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
