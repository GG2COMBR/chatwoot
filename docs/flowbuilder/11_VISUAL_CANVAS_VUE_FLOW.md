# 11. Canvas Visual Drag-and-Drop com Vue Flow

## 1. Visão Geral

O editor visual do Flowbuilder utiliza o `@vue-flow/core` como motor de grafo headless integrado ao Chatwoot, renderizando todos os nós com componentes nativos e utilitários Tailwind CSS.

- **Arquivo Principal**: `app/javascript/dashboard/routes/dashboard/settings/customFlows/Editor.vue`.
- **Componente de Nó**: `app/javascript/dashboard/routes/dashboard/settings/customFlows/components/CustomNode.vue`.
- **Rota no Dashboard**: `/app/accounts/:accountId/settings/custom_flows/:flowId/edit`.

---

## 2. Recursos do Canvas

1. **Manipulação de Grafo**:
   - Arraste livre de nós pela grade com snap e atualização de coordenadas `position: { x, y }`.
   - Conexão magnética entre pontos de saída (`Handle type="source"`) e pontos de entrada (`Handle type="target"`).
   - Validação de integridade e feedback visual de seleção (`ring-2 ring-n-brand`).
   - Remoção de nós e arestas com propagação imediata para o estado local.

2. **Navegação e Controles**:
   - Grade de fundo (`<Background :gap="16" />`).
   - Barra de controles flutuante (`<Controls position="bottom-left" />`) com zoom in, zoom out, fit view e lock.

3. **Ações do Topbar**:
   - **Salvar Alterações**: Envia o estado serializado do grafo (`nodes` e `edges`) para `PATCH /api/v1/accounts/:account_id/custom_flows/:id`.
   - **Publicar Fluxo**: Valida que o grafo possui nó inicial (`start`) e nós conexos, ativando o fluxo para produção (`published`).
   - Badge dinâmico de status (`Publicado` em verde esmeralda, `Rascunho` em âmbar).

---

## 3. Catálogo de Tipos de Nós Suportados

| Tipo (`type`) | Nome Amigável | Cor Semântica | Descrição |
|---|---|---|---|
| `start` | Início da Conversa | Verde Esmeralda | Ponto de entrada disparado por mensagem WhatsApp ou Kanban |
| `message` | Enviar Mensagem | Azul Chatwoot | Mensagem de texto simples enviada ao cliente |
| `interactive_buttons` | Pergunta com Botões | Âmbar | Mensagem interativa com botões de resposta rápida da Meta |
| `interactive_list` | Lista Interativa | Âmbar | Menu com lista de seções e opções |
| `business_hours` | Horário de Atendimento | Azul Cobalto | Avalia expediente da equipe e ramifica aberto/fechado |
| `ai_fallback` | Assistente IA Bedrock | Roxo Generativo | Resposta inteligente contextual via Claude 3.5 / Nova Lite |
| `human_transfer` | Transferir para Atendente | Verde Teal | Atribui a conversa para equipe e atendente humano |
| `kanban_stage_change` | Mover Estágio no Kanban | Índigo Funil | Atualiza o cartão de coluna no quadro Kanban em tempo real |
| `async_api` | Consulta Externa / ERP | Ciano Integração | Dispara consulta assíncrona com mensagem imediata de espera |
| `finish` | Encerrar Conversa (CSAT) | Rosa Avermelhado | Encerra a sessão e envia pesquisa de satisfação |
