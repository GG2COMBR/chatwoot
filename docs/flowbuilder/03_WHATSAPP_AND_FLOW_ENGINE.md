# 03. Mensagens Interativas WhatsApp, Nós Assíncronos & IA Bedrock

## 1. Mensagens Interativas WhatsApp (Meta Cloud API)

Para proporcionar uma experiência profissional e evitar que o cliente precise digitar números em menus de texto:

### A. Quick Reply Buttons (Até 3 Opções)
- Renderizadas nativamente pelo WhatsApp como botões de toque rápido.
- Utilizadas para confirmações simples (ex: `[Sim, quero comprar]`, `[Não, obrigado]`, `[Falar com Atendente]`).

### B. Interactive Lists (4 a 10 Opções)
- Renderizadas como um menu expansível com título de seção e descrição.
- Utilizadas para categorias de produtos, menus principais e seleções de departamentos.

### C. Fallback Automático para Texto
- Caso a mensagem seja disparada em um canal web widget ou SMS (que não suportam botões nativos da Meta), o serviço `Custom::Flows::InteractiveMessageService` converte automaticamente a lista de botões em um menu de texto numerado amigável.

---

## 2. Processamento Assíncrono para Nós Pesados (`AsyncActionJob`)

Quando a URA precisa executar uma ação pesada (como consultar o ERP, buscar segunda via de boleto ou consultar status de pedido no Magento):

1. **Mensagem Imediata de Feedback (Zero Vácuo)**:
   - O motor envia instantaneamente uma mensagem no WhatsApp configurada no nó (ex: *"⏳ Aguarde um instante enquanto consultamos seus pedidos..."*).
2. **Execução em Segundo Plano**:
   - O trabalho é enfileirado no Sidekiq (`Custom::Flows::AsyncActionJob`) na fila `:flows_processing`.
   - A thread web do Chatwoot é liberada imediatamente.
3. **Retomada Automática**:
   - Assim que a API externa responde, o job retoma o fluxo no próximo nó, entregando o resultado formatado no WhatsApp.

---

## 3. Fallback Contextual com AWS Bedrock

Quando o cliente digita uma dúvida que não corresponde a nenhuma das opções do menu:

1. **Nó `ai_fallback` / `ai_agent`**:
   - Invoca a Converse API do AWS Bedrock (`amazon.nova-lite-v1:0` ou `anthropic.claude-3-5-haiku`).
   - Fornece o System Prompt com as diretrizes da empresa e o histórico recente da conversa.
2. **Respostas com Limite de Tokens e Salvaguardas**:
   - Respostas curtas, objetivas e com formatação compatível com WhatsApp (negrito `*`, quebra de linha).
   - Se o cliente solicitar explicitamente falar com um atendente, o Bedrock ramifica para o nó de transbordo humano (`handoff`).
