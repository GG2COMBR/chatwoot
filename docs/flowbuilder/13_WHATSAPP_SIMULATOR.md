# 13. Simulador de WhatsApp Embutido no Canvas

## 1. Visão Geral

O Flowbuilder inclui um simulador interativo de WhatsApp (`WhatsAppSimulator.vue`) acessível diretamente pelo editor visual através do botão **"Testar Fluxo"**. Ele permite que gestores de negócios e atendentes experimentem o fluxo conversacional exatamente como um cliente real o vivenciaria em seu smartphone, sem custos de envio de mensagens nem necessidade de conexão com o número oficial do WhatsApp.

- **Componente**: `app/javascript/dashboard/routes/dashboard/settings/customFlows/components/WhatsAppSimulator.vue`.
- **Acesso**: Botão "Testar Fluxo" no topo do editor de fluxo.

---

## 2. Funcionalidades da Simulação

1. **Moldura Realista de Smartphone**:
   - Design fiel à interface do WhatsApp com barra de status superior, avatar do canal e sinalizador de status *online*.
   - Balões com formatação nativa (verde escuro para cliente, cinza-azulado para robô).

2. **Interatividade com Botões Rápidos e Menus**:
   - Botões interativos renderizados abaixo da mensagem do robô.
   - Ao clicar em qualquer botão, o simulador registra a resposta do cliente e avança imediatamente para o próximo nó conectado no grafo.

3. **Digitação Livre e Simulação de IA**:
   - Barra de digitação inferior com campo de texto e botão de envio (avião de papel).
   - O usuário pode digitar qualquer texto e pressionar Enter para testar os caminhos livres ou respostas do assistente IA Bedrock.

4. **Eventos de Sistema Visíveis**:
   - Sinaliza visualmente ações que ocorrem nos bastidores:
     - 📊 *Cartão movido no Kanban para: "[Nome do Estágio]"*
     - 👤 *Conversa transferida para a equipe de atendimento humano*
     - ⏰ *Horário de atendimento verificado*
     - ⭐ *Pesquisa de Satisfação (CSAT) enviada ao cliente*
     - 🏁 *Sessão finalizada*

5. **Controles Rápidos**:
   - Botão **Reiniciar Simulação** (ícone de recarregar) para reiniciar a partir do nó `start`.
   - Botão **Fechar** para retornar à edição do canvas.
