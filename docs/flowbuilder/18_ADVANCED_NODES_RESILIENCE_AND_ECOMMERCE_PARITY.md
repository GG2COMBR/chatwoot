# 18. Nós Avançados, Resiliência, Gestão de Atributos e Paridade E-commerce (Magento)

> **Documento Canônico de Continuidade Técnica do Flowbuilder**  
> **Branch Atual:** `feat/68`  
> **Status dos Testes:** 126 exemplos RSpec, 0 falhas (`spec/custom/`)  
> **Seed de Homologação:** `Custom::SeedService.perform!` (Conta GG2 Tecnologia)

---

## 1. Visão Geral da Entrega & Estado Atual

Nesta etapa do projeto, o Flowbuilder do Chatwoot Vanilla recebeu capacidades avançadas de automação, resiliência de rede e paridade funcional total com o fluxo de compras e-commerce do `hsb-chat-ia-v4`.

### Principais Pilares Implementados:
1. **Fechamento de Atendimento com Motivo Formal (`finish`)**: Gravação de motivo em atributo personalizado de conversa (`conversation.custom_attributes`).
2. **Status da Conversa & Métricas de Tempo por Etapa (*Dwell Time*)**: Substituição de tags globais por campos personalizados da conversa, com registro contínuo de tempo gasto por etapa (`step_history`).
3. **Seleção Segura de Atributos Personalizados via `<select>`**: Eliminação de campos de texto aberto, conectando diretamente com a API e Store de `CustomAttributeDefinition` (modelo `conversation_attribute`), com suporte a *empty state* e criação rápida sob demanda.
4. **Mover no Kanban Encadeado & Resiliente (`kanban_stage_change`)**: Seleção de Funil ➔ Etapa com rota dedicada (`kanban_options`) e orientação amigável caso não existam funis cadastrados.
5. **Tratamento de Falhas com Retentativas (`try_catch`)**: Nós de contingência com saídas ramificadas (`try` e `catch`) para isolar falhas de APIs externas.
6. **Gerenciamento de Etiquetas (`manage_labels`)**: Aplicação e remoção de tags na conversa ou no contato.
7. **Chamadas Assíncronas com Feedback Imediato (`async_api`)**: Processamento em background na fila `:flows_processing` com saídas dedicadas (`success` e `error`).
8. **Slot Filling Conversacional Multi-turn via LLM (`ai_agent`)**: Retenção do usuário no nó de IA até a extração de campos obrigatórios (CPF, CEP, etc.).
9. **Mocks de E-commerce Magento (`Custom::Mocks::EcommerceMockService`)**: Operações mockadas para consulta de cliente, catálogo de produtos, cálculo de frete/cotação e geração de pedido com Pix copia-e-cola.

---

## 2. Novos Nós & Catálogo Visual

| Tipo do Nó | Nome Amigável | Entradas / Saídas | Finalidade |
|---|---|---|---|
| `try_catch` | Tratamento de Erro (Try/Catch) | Entrada Top / Saídas: `try` e `catch` | Executa retentativas e desvia para contingência ao atingir `max_retries`. |
| `manage_labels` | Gerenciar Etiquetas | Entrada Top / Saída Bottom (Pass-through) | Adiciona ou remove etiquetas oficiais na conversa ou no contato. |
| `condition_router` | Decisão Condicional (Se/Senão) | Entrada Top / Saídas: `true` e `false` | Avalia variáveis de contexto com operadores (`equals`, `not_equals`, `present`, `blank`, `contains`). |
| `async_api` | Processamento Assíncrono / API | Entrada Top / Saídas: `success` e `error` | Dispara `AsyncActionJob` na fila prioritária `:flows_processing` e comuta o step via worker. |
| `finish` | Encerrar com Motivo | Entrada Top / Sem saída | Resolve a conversa e grava `closure_reason` no campo `closure_attribute_key`. |
| `ai_agent` | Assistente IA com Slot Filling | Entrada Top / Saída Bottom | Mantém o cliente no nó até extrair os campos de `required_fields` via LLM. |
| `kanban_stage_change` | Mover no Funil / Kanban | Entrada Top / Saída Bottom (Pass-through) | Move o card do contato no pipeline selecionado. |

---

## 3. Arquitetura de Execução & Comutação Automática (`ExecutionEngine`)

### Pass-through Nodes
Os nós `kanban_stage_change`, `manage_labels`, `condition_router` e `try_catch` são definidos em `PASS_THROUGH_NODES`. Eles não dependem de mensagem do cliente:
```ruby
PASS_THROUGH_NODES = %w[kanban_stage_change manage_labels condition_router try_catch].freeze
```
Ao serem executados, o `ExecutionEngine` chama `auto_advance_pass_through!`, avançando imediatamente para a próxima etapa conectada de acordo com as condições avaliadas.

### Rastreamento de Dwell Time
A cada nó executado, o método `track_node_status_and_dwell_time!(node)`:
1. Atualiza `conversation.custom_attributes[status_attr_key] = step_status_value` (se configurado).
2. Calcula o tempo decorrido no nó anterior (`dwell_time_seconds` e `dwell_time_minutes`).
3. Registra a entrada no nó atual em `session.context['step_history']`.

---

## 4. Gestão Segura de Atributos Personalizados (`custom_attributes`)

Para evitar inconsistências com atributos inexistentes ou erros de digitação:
1. **Frontend (`Index.vue`, `Editor.vue`, `NodeConfigDrawer.vue`)**:
   - Conectado à store Vuex via `store.dispatch('attributes/get')` e `useMapGetter('attributes/getConversationAttributes')`.
   - Dropdown `<select>` exibindo `🏷️ Nome do Atributo (slug_chave)`.
   - Empty state automático com botão de ação rápida: `+ Criar Atributo Padrão` (cria `etapa_fluxo` ou `motivo_encerramento` via API nativa).
2. **Backend (`SeedService.rb`)**:
   - Cria formalmente na conta GG2:
     - `etapa_fluxo`: Modelo `conversation_attribute`, tipo `text`.
     - `motivo_encerramento`: Modelo `conversation_attribute`, tipo `text`.

---

## 5. Mocks de Integração com o Magento (`EcommerceMockService`)

Localização: `custom/app/services/custom/mocks/ecommerce_mock_service.rb`

| Operação | Parâmetros de Entrada | Saída no Contexto |
|---|---|---|
| `magento_customer_lookup` | `cpf`, `phone` | `customer_found: true/false`, `customer_tier`, `credit_limit` |
| `magento_search_products` | `category_id`, `query` | `products: [{ id, name, price, stock }]` |
| `magento_create_quote` | `items`, `cep` | `quote_id`, `subtotal`, `shipping_amount`, `total_amount` |
| `magento_place_order` | `quote_id`, `payment_method` | `order_id`, `amount`, `pix_code`, `status: pending_payment` |

---

## 6. Seed da Jornada Completa de E-commerce

O fluxo `"🛍️ Jornada de Compra Completa — E-commerce & URA"` é gerado automaticamente pelo seed:
```
[Início] 
  ➔ [IA Slot Filling: Coleta CPF/CEP] 
  ➔ [Async API: Consulta Magento] 
  ➔ [Try/Catch: Resiliência] 
  ➔ [Condicional: Cliente Encontrado?] 
      ➔ Sim: [Catálogo de Produtos] ➔ [Cotação & Frete Sedex] ➔ [Botões Pagamento] ➔ [Gerar Pedido Magento] ➔ [Entrega Pix Copia-e-Cola com {{context.pix_code}}] ➔ [Gerenciar Etiquetas] ➔ [Mover no Funil Kanban] ➔ [Encerrar com Motivo]
      ➔ Não: [Novo Cadastro Express] ➔ [Transbordo Humano com Nota Privada]
```

---

## 7. Comandos Essenciais para o Desenvolvedor / Novos Agentes

### Execução de Testes Automatizados (RSpec)
```bash
# Sempre inicializar o rbenv e definir as variáveis de ambiente locais do Postgres
eval "$(rbenv init -)" && POSTGRES_HOST=127.0.0.1 POSTGRES_USERNAME=postgres POSTGRES_PASSWORD=postgres bundle exec rspec spec/custom/

# Teste unitário focado do motor de execução
eval "$(rbenv init -)" && POSTGRES_HOST=127.0.0.1 POSTGRES_USERNAME=postgres POSTGRES_PASSWORD=postgres bundle exec rspec spec/custom/services/custom/flows/execution_engine_spec.rb
```

### Execução do Seeder de Homologação
```bash
eval "$(rbenv init -)" && POSTGRES_HOST=127.0.0.1 POSTGRES_USERNAME=postgres POSTGRES_PASSWORD=postgres bundle exec rails runner "Custom::SeedService.perform!"
```

### Git Workflow & Isolamento
- **Branch de trabalho**: `feat/68` criada a partir de `staging`.
- **Regra de Isolamento**: Todo código novo no backend deve residir sob `custom/` sob o namespace `Custom::`. Zero modificação nas pastas do core (`app/`, `config/`, `db/`).
