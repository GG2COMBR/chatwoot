# 04. Horários de Atendimento Flexíveis & Roteamento por Perfil

## 1. O Problema da Ausência Humana

Quando a URA transborda para atendimento humano, nem sempre há operadores disponíveis (ex: noites, finais de semana ou feriados).
Para garantir que o cliente **nunca fique sem resposta nem "no vácuo"**, o sistema implementa validação de horários em tempo real.

---

## 2. Validador de Horários (`Custom::Flows::ScheduleEvaluatorService`)

- **Localização**: `custom/app/services/custom/flows/schedule_evaluator_service.rb`.
- Avalia a grade semanal do time ou da caixa de entrada em fuso horário local (`America/Sao_Paulo` por padrão):
  ```ruby
  Custom::Flows::ScheduleEvaluatorService.open_now?(target, timezone: 'America/Sao_Paulo')
  ```
- Suporta:
  - Horários de início e fim por dia da semana (ex: Seg-Sex das 08:00 às 18:00).
  - Dias com expediente parcial (ex: Sábados das 08:00 às 12:00).
  - Dias totalmente fechados (ex: Domingos).
  - Turnos contínuos 24/7.
  - Avaliação nativa contra `inbox.working_hours` ou hash de configuração visual do nó (`weekly_schedule`).

---

## 3. Comportamento Fora do Expediente (Out of Office) & Roteamento Atômico

Ao executar o transbordo via `route_and_handoff!(conversation, team, config)`:

1. **Se Aberto**:
   - Atribui imediatamente o time à conversa (`team: team`).
   - Define status como `open` para os operadores humanos.
2. **Se Fechado (Fora do Expediente)**:
   - Atribui o time mantendo a conversa com status `pending` (evitando alertas fora do turno).
   - Interpola e envia mensagem amigável de ausência:
     > *"Olá {{contact.name}}! O time {{team.name}} atende em horário comercial."*
   - Garante que a fila do dia seguinte esteja previamente organizada no painel.

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
