# Flowbuilder — Integração Canônica de Disparo via Regras de Automação (Automation Rules)

## 1. Visão Geral
Esta arquitetura substitui o mecanismo de disparo engessado (*"WhatsApp Padrão"*) por uma integração completa com o **Motor de Regras de Automação (`Automation Rules`)** nativo do Chatwoot.
Com isso, os fluxos tornam-se componentes puramente modulares e reutilizáveis, disparados por qualquer evento ou critério da plataforma (caixas de entrada, mensagens com palavras-chave, etiquetas, atributos personalizados, estágios de Kanban, etc.).

---

## 2. Topologia do Disparo & Ciclo de Vida da Sessão

```mermaid
flowchart TD
    subgraph Chatwoot Core
        Msg[Mensagem Recebida ou Conversa Criada] --> AutoListener[AutomationRuleListener]
        AutoListener --> ActionService[AutomationRules::ActionService]
    end

    subgraph Custom Layer
        ActionService -->|include Custom::ActionService| TriggerFlow[action: trigger_flow(flow_id)]
        TriggerFlow --> Mutex[Redis Lock: conversation:ID:flow_trigger]
        Mutex --> ClosePrev[Encerra sessões ativas prévias da conversa]
        ClosePrev --> CreateSession[Custom::FlowSession.create!]
        CreateSession --> Engine[Custom::Flows::ExecutionEngine.process!]
        Engine --> StartNode[Nó Start - Pass Through]
        StartNode --> FirstAction[Primeiro Nó Funcional: URA / Mensagem]
    end

    subgraph Continuidade da Conversa
        CustomerReply[Mensagem do Cliente] --> CustomFlowListener[Custom::FlowListener]
        CustomFlowListener --> ActiveCheck{Sessão ativa e sem atendente?}
        ActiveCheck -->|Sim| ProcessJob[ProcessFlowJob na fila :flows_processing]
        ActiveCheck -->|Não| Ignore[Ignora / Mantém atendimento normal]
        HumanMsg[Mensagem de Atendente Humano] --> Interruption[handle_human_message: pausa o fluxo]
    end
```

---

## 3. Componentes Implementados na Camada `custom/`

1. **`Custom::AutomationRule`** (`custom/app/models/custom/automation_rule.rb`):
   - Módulo acoplado via `AutomationRule.prepend_mod_with('AutomationRule')`.
   - Adiciona `'trigger_flow'` à lista de ações suportadas (`actions_attributes`), garantindo conformidade com a validação nativa de formato de ações do Chatwoot.

2. **`Custom::ActionService`** (`custom/app/services/custom/action_service.rb`):
   - Módulo acoplado via `ActionService.include_mod_with('ActionService')`.
   - Implementa o método `trigger_flow(flow_ids)`:
     - Localiza o fluxo publicado da conta.
     - Aplica mutex distribuído no Redis (`Custom::Flows::LockService`) para evitar execuções concorrentes.
     - Finaliza sessões ativas prévias da mesma conversa, marcando `replaced_by_flow_id`.
     - Inicializa uma nova `Custom::FlowSession` e executa o `ExecutionEngine.process!`.

3. **`Custom::AsyncDispatcher` & `Custom::FlowListener`** (`custom/app/dispatchers/custom/` e `custom/app/listeners/custom/`):
   - Acoplado via `AsyncDispatcher.prepend_mod_with('AsyncDispatcher')`.
   - Gerencia mensagens subsequentes do cliente dentro de uma sessão ativa sem atribuir atendente humano.
   - Detecta intervenção humana e marca a sessão como `interrupted_by_human`.

4. **Nó `start` Pass-Through** (`custom/app/services/custom/flows/execution_engine.rb`):
   - Adicionado a `PASS_THROUGH_NODES`, permitindo que ao iniciar a sessão, o grafo transite imediatamente do ponto de partida para o primeiro nó interativo.

---

## 4. Frontend & Limpeza de Código Morto

- **Adição da Ação `trigger_flow`**:
  - `constants.js`: Adicionado `{ key: 'trigger_flow', label: 'TRIGGER_FLOW', inputType: 'search_select' }`.
  - `automationHelper.js`: Mapeamento do ícone `i-lucide-git-branch` e opções de fluxos publicados.
  - `useAutomationValues.js`: Carregamento reativo e sob demanda de fluxos publicados via `CustomFlowsAPI.get()`.
  - `i18n`: Chave `"TRIGGER_FLOW": "Disparar Fluxo do Flowbuilder"` / `"Trigger Flowbuilder Flow"`.
- **Eliminação de Código Morto**:
  - Removido o `<select v-model="newFlowTrigger">` do modal de criação de fluxo (`Index.vue`), que continha a opção arbitrária e engessada *"WhatsApp Padrão"*.
  - Refatorado `formatTrigger` na listagem para indicar claramente *"Automações & Eventos"* ou *"Gatilho Kanban"*.
  - Atualizados os dados de seed para `trigger_type: 'automation'`.
