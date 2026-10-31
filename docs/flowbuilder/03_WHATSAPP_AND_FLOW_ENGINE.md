# 03. Mensagens Interativas WhatsApp, Nós Assíncronos & IA Bedrock

## 1. Mensagens Interativas WhatsApp (Meta Cloud API)

Para proporcionar uma experiência profissional e evitar que o cliente precise digitar números em menus de texto:

### A. Quick Reply Buttons (Até 3 Opções)
- Renderizadas nativamente pelo WhatsApp como botões de toque rápido (`interactive.button`).
- Limite de caracteres: 20 caracteres por título de botão (truncamento seguro automático).
- Utilizadas para confirmações simples (ex: `[🛍️ Quero Comprar]`, `[🛠️ SAC]`, `[👤 Atendente]`).

### B. Interactive Lists (4 a 10 Opções)
- Renderizadas como um menu expansível com título de seção e descrição (`interactive.list`).
- Limite de caracteres: 24 caracteres por título de linha e 72 caracteres por descrição.
- Utilizadas para categorias de produtos, menus principais e seleções de departamentos.

### C. Fallback Automático para Texto
- Caso a mensagem seja disparada em um canal web widget ou SMS (que não suportam botões nativos da Meta), o serviço `Custom::Flows::InteractiveMessageService` converte automaticamente a lista de botões em um menu de texto numerado amigável (`1. Opção A\n2. Opção B`).
- Invocação unificada:
  ```ruby
  Custom::Flows::InteractiveMessageService.dispatch!(conversation, text, options)
  ```

---

## 2. Processamento Assíncrono para Nós Pesados (`AsyncActionJob`)

Quando a URA precisa executar uma ação pesada (como consultar o ERP, buscar segunda via de boleto ou consultar status de pedido no Magento):

1. **Mensagem Imediata de Feedback (Zero Vácuo)**:
   - O nó do tipo `async_action` envia instantaneamente uma mensagem no WhatsApp configurada no campo `wait_message` ou `feedback_message` (ex: *"⏳ Aguarde um instante enquanto consultamos seus dados..."*).
   - O texto enviado fica registrado no contexto da sessão (`last_wait_message`).
2. **Execução em Segundo Plano**:
   - O trabalho é enfileirado no Sidekiq (`Custom::Flows::AsyncActionJob`) na fila dedicada `:flows_processing`.
   - Adquire mutex distribuído no Redis (`session:<session_id>`) para garantir isolamento atômico e proteção contra reentrância.
   - A thread web do Chatwoot é liberada imediatamente em menos de 10ms.
3. **Mapeamento de Ações Suportadas**:
   - `mock` / `ecommerce_mock` / `mock_erp`: Encaminha para `Custom::Mocks::EcommerceMockService.dispatch(action_config)`.
   - `http_request`: Realiza chamada HTTP externa via HTTParty (métodos `get`, `post`, etc.) com timeout configurado de 5s.
4. **Retomada Automática do Grafo**:
   - O resultado da ação é gravado no JSONB `context` da sessão (`action_result` e `last_action_node`).
   - O job invoca `Custom::Flows::ExecutionEngine.process!(session, content: result[:status], action_result: result)`.
   - As arestas que partem do nó `async_action` podem verificar a condição por status (`condition: { status: 'success' }` ou `condition: { status: 'error' }`) ou seguir pela aresta default.

---

## 2.1. Sistema Neutro de Mocks Corporativos (`Custom::Mocks::EcommerceMockService`)

Permite desenvolvimento, testes automatizados e validações de negócios com zero acoplamento externo:

- **Localização**: `custom/app/services/custom/mocks/ecommerce_mock_service.rb`.
- **Operações Suportadas**:
  1. `validate_cpf`: Sanitiza pontuações e valida formato (11 dígitos). Retorna dados do cliente (Nome, Status, Tier VIP).
  2. `recent_orders`: Retorna lista simulada de pedidos recentes com código de rastreamento e status logístico.
  3. `order_status`: Retorna detalhes de rastreamento com link direto para consulta nos Correios.
  4. `generate_boleto`: Retorna código de barras formatado, link de PDF seguro e vencimento dinâmico.
  5. `reseller_balance`: Retorna saldo disponível, comissões pendentes e nível de revendedora consignada.
- **Transição Transparente para Produção**:
  - Quando as APIs reais forem plugadas, basta alterar o tipo do nó no Flowbuilder ou direcionar as chamadas via variável de ambiente sem qualquer alteração no motor de execução.

---

## 3. Fallback Contextual com AWS Bedrock (`Custom::Ai::BedrockService`)

Quando o cliente digita uma dúvida que não corresponde a nenhuma das opções do menu ou após retentativas inválidas:

1. **Nó `ai_fallback` / `ai_agent`**:
   - Invoca o serviço `Custom::Ai::BedrockService.chat(prompt, options)`.
   - Utiliza nativamente a gem `RubyLLM` com suporte a AWS Bedrock Converse API (`amazon.nova-lite-v1:0` por padrão ou `anthropic.claude-3-5-haiku`).
   - Carrega as credenciais via `CAPTAIN_BEDROCK_ACCESS_KEY_ID`, `CAPTAIN_BEDROCK_SECRET_ACCESS_KEY` e região `CAPTAIN_BEDROCK_REGION` (`us-east-1`).
2. **Respostas com Limite de Tokens e Salvaguardas**:
   - Limite configurável de tokens (padrão: 300 tokens) e baixa temperatura (`temperature: 0.3`) para evitar alucinações.
   - Formatação compatível com WhatsApp (sem blocos de código markdown desnecessários, negritos com `*` e quebras de linha limpas).
   - Registra no contexto da sessão (`ai_result`, `last_ai_query`, `last_ai_response`).
3. **Resiliência e Fallback Seguro**:
   - Caso a API do Bedrock apresente indisponibilidade ou rate limit, o serviço captura a exceção de forma transparente e retorna resposta de contingência amigável informando a transferência para atendimento humano, sem quebrar o fluxo.

---

## 3.1. Detector de Intenção de Transbordo Humano (`Custom::Ai::HandoffDetectorService`)

Garante que qualquer desejo expresso pelo cliente de falar com um atendente humano seja atendido imediatamente sem insistência de IA:

- **Localização**: `custom/app/services/custom/ai/handoff_detector_service.rb`.
- **Funcionamento**:
  - Antes de despachar a mensagem para o LLM, o método `Custom::Ai::HandoffDetectorService.human_intent?(prompt)` inspeciona padrões semânticos e termos-chave (*"falar com atendente"*, *"atendente humano"*, *"pessoa real"*, *"suporte humano"*, *"operador"*).
  - Caso detectado:
    1. A chamada ao Bedrock é abortada imediatamente para economizar tokens e latência.
    2. O motor aciona `trigger_human_handoff` direcionando a conversa para a equipe configurada (`node.dig(:data, :handoff_team)` ou equipe padrão `SAC`).
    3. Atualiza o status da sessão para `handoff` e grava `handoff_reason: 'human_intent_detected'` no contexto.
    4. Envia imediatamente a mensagem de confirmação de transferência para o cliente no WhatsApp.

---

## 4. Guarda Humano x Robô & Elegibilidade Estrita (`Custom::Flows::EligibilityService`)

Para eliminar qualquer concorrência entre robôs e atendentes humanos:

### A. Critérios de Elegibilidade (`Custom::Flows::EligibilityService.eligible?`)
- **Conversas com Atendente Atribuído**: Se `assignee_id` estiver preenchido, o motor ignora imediatamente a mensagem.
- **Conversas Abertas**: Se o status da conversa for `open` (em atendimento), o motor do fluxo nunca dispara mensagens.
- **Mensagens Internas e Privadas**: Notas privadas ou mensagens de saída de agentes são filtradas imediatamente.
- **Existência de Fluxo Publicado**: A conta deve possuir ao menos um fluxo com status `published`.

### B. Interrupção Imediata por Ação Humana (`handle_human_message`)
- Sempre que um atendente humano envia uma mensagem pública na conversa, qualquer sessão ativa da URA é imediatamente cancelada com status `interrupted_by_human` e registra o timestamp da interrupção no contexto JSONB.

### C. Reabertura por Cliente (`ensure_pending_state_on_reopen`)
- Se uma conversa resolvida (`resolved`) ou suspensa (`snoozed`) for reaberta por uma mensagem do cliente sem atendente atribuído, o status é alterado/mantido como `pending`, permitindo o início ordenado de uma nova sessão na URA sem poluir as caixas dos atendentes humanos até o handoff.

---

## 5. Motor de Execução de Grafo & Transições (`Custom::Flows::ExecutionEngine`)

Responsável pela interpretação do snapshot do fluxo e avanço do ponteiro da sessão conversacional:

- **Localização**: `custom/app/services/custom/flows/execution_engine.rb`.
- **Invocação**: `Custom::Flows::ExecutionEngine.process!(session, input_data)`.
- **Regras de Transição**:
  1. **Nó Inicial**: Se `current_node_id` for nulo, localiza o nó raiz (sem arestas de entrada ou do tipo `start`) e o executa.
  2. **Arestas Específicas**: Compara `button_id`, texto exato (`value`) ou palavras-chave (`keyword`).
  3. **Aresta Padrão (Fallback)**: Caso nenhuma condição específica case com a entrada, segue pela aresta padrão (`default: true`).
  4. **Retentativas e Fuga**: Se nenhuma aresta casar, contabiliza retentativas no contexto e, após 2 falhas, ramifica automaticamente para o nó `ai_fallback`.
- **Mapeamento de Ações**: Dispara handlers especializados para cada tipo de nó (`message`, `interactive_buttons`, `interactive_list`, `team_assignment`, `ai_fallback`, `finish`).
