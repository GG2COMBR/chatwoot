# 12. Catálogo de Blocos No-Code e Gaveta de Configuração

## 1. Visão Geral

Para garantir a usabilidade no-code por equipes de negócios e gestores não técnicos, o Flowbuilder fornece:
1. **Catálogo Visual de Blocos**: Painel flutuante com blocos organizados por função e identificados por cores semânticas e ícones.
2. **Gaveta Lateral Deslizante (Drawer)**: Interface contextual que se abre ao selecionar qualquer nó do canvas, exibindo formulários simples com linguagem amigável em português (sem jargões como *JSON*, *Webhooks* ou *Handlers*).

---

## 2. Blocos Disponíveis no Catálogo

- 💬 **Enviar Mensagem (`message`)**: Envia mensagens de texto no WhatsApp com suporte a quebras de linha e emojis.
- 🔘 **Pergunta com Botões (`interactive_buttons`)**: Menu interativo com até 3 botões de resposta rápida da Meta.
- ⏰ **Horário de Atendimento (`business_hours`)**: Validação de expediente da equipe com mensagem personalizada de ausência.
- 🤖 **Assistente IA Bedrock (`ai_fallback`)**: Resposta inteligente contextual via modelos Amazon Nova Lite ou Anthropic Claude 3.5.
- 👤 **Transferir Atendente (`human_transfer`)**: Roteamento da conversa para a fila de atendimento humano.
- 📊 **Mover no Kanban (`kanban_stage_change`)**: Avança o cartão de coluna no funil comercial/SAC em tempo real via ActionCable.
- ⚡ **Consulta ERP / Mocks (`async_api`)**: Execução de operações como Consulta de CPF, Pedidos Recentes ou Saldo de Revendedora em background com mensagem imediata de espera.
- 🏁 **Encerrar Conversa (`finish`)**: Finalização da sessão com mensagem de despedida e disparo de pesquisa de satisfação (CSAT).

---

## 3. Comportamento da Gaveta de Edição

- **Abertura**: Ao clicar em qualquer bloco no canvas (`@node-click`).
- **Validação em Tempo Real**: Os campos são atualizados reativamente no nó selecionado.
- **Fechamento**: Botão "Concluir Edição" ou clique no botão de fechar (X), mantendo o grafo consistente para persistência.
