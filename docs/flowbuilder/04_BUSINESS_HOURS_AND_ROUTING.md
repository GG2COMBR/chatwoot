# 04. Horários de Atendimento Flexíveis & Roteamento por Perfil

## 1. O Problema da Ausência Humana

Quando a URA transborda para atendimento humano, nem sempre há operadores disponíveis (ex: noites, finais de semana ou feriados).
Para garantir que o cliente **nunca fique sem resposta nem "no vácuo"**, o sistema implementa validação de horários em tempo real.

---

## 2. Validador de Horários (`Custom::Flows::ScheduleEvaluatorService`)

- Avalia a grade semanal do time ou da caixa de entrada em fuso horário local (`America/Sao_Paulo` por padrão).
- Suporta:
  - Horários de início e fim por dia da semana (ex: Seg-Sex das 08:00 às 18:00).
  - Dias com expediente parcial (ex: Sábados das 08:00 às 12:00).
  - Dias totalmente fechados (ex: Domingos).
  - Turnos contínuos 24/7.

---

## 3. Comportamento Fora do Expediente (Out of Office)

Quando o transbordo ocorre fora do horário, o nó `handoff` ou o nó condicional `business_hours` permite configurar:

1. **Mensagem Personalizada com Interpolação de Variáveis**:
   - O gestor edita o texto livremente no painel:
     > *"Olá {{contact.name}}! Nosso time {{team.name}} atende de segunda a sexta, das 08h às 18h. Já registramos sua mensagem e responderemos assim que abrirmos!"*
2. **Ações Configuráveis**:
   - `send_message_and_queue`: Envia a mensagem de ausência e mantém o ticket atribuído à equipe com status `pending` para que a fila já apareça organizada para os atendentes no início do expediente.
   - `fallback_to_ai`: Transfere para a IA Bedrock tirar dúvidas gerais, avisando que o atendente humano responderá depois.
   - `branch_out`: Ramifica para outro caminho visual no canvas do Flowbuilder.

---

## 4. Segmentação por Perfil de Cliente e Roteamento por Equipe

Clientes com perfis diferentes recebem tratamento e horários diferenciados:

1. **Identificação**: O cliente informa CPF, CNPJ ou telefone (ou identificado via sessão WhatsApp).
2. **Consulta de Perfil**: Nó de API/Mock busca o nível do cliente (ex: `tier = "VIP"`, `"REVENDA_OURO"` ou `"SAC_PADRAO"`).
3. **Roteamento**:
   - **Clientes VIP**: Direcionados para a equipe comercial VIP (expediente estendido até 20h e sábados).
   - **Clientes Padrão**: Direcionados para a equipe de atendimento geral (08h às 18h).
   - **Cobrança / Financeiro**: Direcionados para a equipe financeira.

---

## 5. Seed Idempotente de Demonstração GG2 (`rake custom:seed`)

Para viabilizar homologação imediata e testes do Flowbuilder:

- **Comando**: `docker compose exec rails bundle exec rake custom:seed`
- **Serviço**: `Custom::SeedService.perform!`
- **Estruturas Criadas de Forma Idempotente**:
  - **Conta**: `GG2 Tecnologia` (ID mantido sem duplicação).
  - **Usuários**: `admin@gg2.com.br` (Administrador), `vendas@gg2.com.br` (Agente), `sac@gg2.com.br` (Agente).
  - **Equipes**: `Equipe Vendas`, `Equipe SAC` e `Equipe VIP` (auto-atribuição habilitada).
  - **Caixa de Entrada**: `WhatsApp Oficial GG2` associada ao canal mock de WhatsApp com grade de atendimento semanal ativa (Seg-Sex 08:00-18:00, Sáb-Dom fechado).
  - **Fluxo Visual Demonstrativo**: `Fluxo Geral de Atendimento GG2` em `custom_flows` com status `published`, integrando nós interativos de botões (Vendas, SAC, Falar com Atendente) e nó de IA Bedrock (`amazon.nova-lite-v1:0`).
