# 17. Seletor de Provedores e Modelos Multi-LLM no Flowbuilder

Este documento detalha o suporte a **Múltiplos Provedores de Inteligência Artificial Generativa (Multi-LLM)** dentro do Chatwoot Flowbuilder, permitindo que a equipe de negócios configure de forma 100% visual qual provedor, modelo e parâmetros de inferência devem governar o atendimento automatizado.

---

## 1. Visão Geral & Benefícios Estratégicos

Anteriormente, o assistente inteligente operava com modelo fixo. Com a arquitetura Multi-LLM:

1. **Liberdade de Escolha & Custo vs. Inteligência:** É possível usar modelos ultrarrápidos e econômicos (ex: *Amazon Nova Lite*, *GPT-4o Mini*, *Gemini 1.5 Flash*) para dúvidas simples e triagem, ou modelos de raciocínio profundo (*Claude 3.5 Sonnet*, *Amazon Nova Pro*, *o1-mini*) para diagnósticos complexos de SAC e vendas.
2. **Redundância Operacional:** Facilidade para alternar entre AWS Bedrock, OpenAI, Anthropic ou Gemini caso algum provedor passe por instabilidade momentânea.
3. **Privacidade & Self-Hosted (Ollama):** Suporte nativo ao Ollama para executar modelos locais (*Llama 3.2*, *Mistral*, *DeepSeek R1*) sem envio de dados para provedores externos.
4. **Sem Dependência de TI:** O gestor do fluxo altera o provedor e o modelo em um único clique pela interface visual.

---

## 2. Matriz de Provedores e Modelos Homologados

| Provedor | Modelos Pré-Configurados | Perfil de Uso Recomendado |
|---|---|---|
| **AWS Bedrock** *(Padrão Corporativo)* | `amazon.nova-lite-v1:0`<br>`amazon.nova-pro-v1:0`<br>`anthropic.claude-3-5-haiku-20241022-v1:0`<br>`anthropic.claude-3-5-sonnet-20241022-v2:0`<br>`meta.llama3-3-70b-instruct-v1:0` | Máxima conformidade corporativa AWS, latência baixa em território nacional e segurança de dados. |
| **OpenAI** | `gpt-4o-mini`<br>`gpt-4o`<br>`o1-mini` | Alta capacidade de compreensão contextual, excelente fluência em português e bom equilíbrio custo/benefício. |
| **Anthropic** | `claude-3-5-haiku-latest`<br>`claude-3-5-sonnet-latest` | Raciocínio de alta precisão, fidelidade rigorosa a instruções complexas e tom cordial natural. |
| **Google Gemini** | `gemini-1.5-flash`<br>`gemini-1.5-pro`<br>`gemini-2.0-flash` | Velocidade de inferência ultrarrápida e suporte a janelas massivas de contexto. |
| **Ollama** *(Local / On-Premise)* | `llama3.2`<br>`mistral`<br>`deepseek-r1:8b` | Total privacidade para dados ultra sensíveis, execução em servidores locais sem custo por token. |

> **Nota:** Caso sua empresa utilize um modelo customizado, *fine-tuned* ou versão específica não listada, basta selecionar a opção **"Outro modelo (especificar)..."** e digitar o identificador técnico (ex: `anthropic.claude-3-opus-20240229-v1:0`).

---

## 3. Parametrização na Gaveta Lateral (`NodeConfigDrawer`)

Ao clicar sobre um nó **Assistente IA (Multi-LLM)** no Canvas, a gaveta de configuração disponibiliza os seguintes controles:

### A. Provedor & Modelo
- **Provedor:** Dropdown reativo contendo Bedrock, OpenAI, Anthropic, Gemini e Ollama. Ao alternar, o sistema redefine e filtra os modelos compatíveis automaticamente.
- **Modelo:** Lista dinâmica de modelos de alta performance associados ao provedor selecionado.

### B. Parâmetros de Inferência
- **Temperatura (Criatividade vs. Precisão):**
  - `0.1 (Mais Precisa)`: Respostas determinísticas e estritas. Ideal para consulta a regulamentos e políticas.
  - `0.3 (Equilibrada - Padrão)`: Perfeito equilíbrio entre fluidez natural e precisão das informações.
  - `0.7 (Mais Criativa)`: Tom mais expansivo e consultivo, recomendado para sugestão de mix de produtos.
- **Tokens Máximos (Extensão da Resposta):**
  - `150 tokens`: Respostas curtas (~100 palavras), ideais para leitura rápida no WhatsApp.
  - `300 tokens (Padrão)`: Respostas completas e bem estruturadas (~200 palavras).
  - `600 tokens`: Respostas aprofundadas com instruções passo a passo (~400 palavras).

### C. System Prompt com Variáveis Contextuais
O gestor pode redigir as diretrizes do robô e inserir tags contextuais dinâmicas com um único clique:
- `{{contact.first_name}}`: Primeiro nome do contato (ex: *Gihovani*).
- `{{contact.name}}`: Nome completo cadastrado.
- `{{account.name}}`: Nome da empresa / conta no Chatwoot.

*Exemplo de System Prompt:*
```text
Você é a assistente virtual inteligente da {{account.name}}.
Você está atendendo o cliente {{contact.first_name}}. Seja cordial, simpática e resolutiva.
Tire dúvidas sobre status de pedidos, catálogos e formas de pagamento.
Se não souber a resposta ou o cliente solicitar um atendente, informe que irá transferi-lo.
```

### D. Mensagem de Contingência (Fallback)
Texto amigável disparado automaticamente caso haja indisponibilidade de rede ou término de cota do provedor externo, garantindo que o cliente final nunca fique sem resposta:
> *"Compreendo sua dúvida! Para melhor lhe atender com precisão, vou transferir sua conversa para um atendente humano."*

---

## 4. Visualização no Canvas & Simulador WhatsApp

- **Canvas Visual (`CustomNode.vue`):** O bloco no grafo exibe badge imediato identificando o provedor e o modelo configurados (ex: `IA [openai]: gpt-4o-mini` ou `IA [bedrock]: amazon.nova-lite-v1:0`), permitindo ao arquiteto do fluxo auditar a distribuição de inteligência num piscar de olhos.
- **Simulador WhatsApp (`WhatsAppSimulator.vue`):** Permite testar a experiência do cliente sem precisar enviar mensagens reais no WhatsApp, exibindo a tag correspondente ao modelo que estaria respondendo àquela etapa.

---

## 5. Configuração de Credenciais no Ambiente Backend

O serviço unificado `Custom::Ai::BedrockService` consome de forma segura as seguintes chaves de ambiente:

| Provedor | Variáveis de Ambiente |
|---|---|
| **AWS Bedrock** | `CAPTAIN_BEDROCK_REGION`, `CAPTAIN_BEDROCK_ACCESS_KEY_ID`, `CAPTAIN_BEDROCK_SECRET_ACCESS_KEY` |
| **OpenAI** | `OPENAI_API_KEY` |
| **Anthropic** | `ANTHROPIC_API_KEY` |
| **Google Gemini** | `GEMINI_API_KEY` |
| **Ollama** | `OLLAMA_API_BASE` *(Default: `http://localhost:11434`)* |

Todas as leituras utilizam `ENV.fetch(..., nil)`, prevenindo *crashes* silenciosos ou exceções de boot caso uma chave opcional não esteja definida.
