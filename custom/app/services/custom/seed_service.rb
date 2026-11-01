# frozen_string_literal: true

class Custom::SeedService
  DEFAULT_PASSWORD = 'Password123!'
  ACCOUNT_NAME = 'GG2 Tecnologia'
  WHATSAPP_PHONE = '+5511999999999'

  def self.perform!
    new.perform!
  end

  def perform!
    account = find_or_create_account
    admin, vendas_agent, sac_agent = setup_users(account)
    setup_custom_attributes(account)
    teams = setup_teams(account, vendas_agent, sac_agent)
    inbox = setup_inbox(account, [admin, vendas_agent, sac_agent])
    flow = setup_sample_flow(account)
    purchase_flow = setup_purchase_journey_flow(account)

    { account: account, admin: admin, teams: teams, inbox: inbox, flow: flow, purchase_flow: purchase_flow }
  end

  private

  def find_or_create_account
    account = Account.where('lower(name) = ?', ACCOUNT_NAME.downcase).first || Account.new(name: ACCOUNT_NAME)
    account.locale = 'pt_BR'
    account.save!
    account
  end

  def setup_users(account)
    admin = find_or_create_user(
      email: 'admin@gg2.com.br',
      name: 'Admin GG2',
      role: :administrator,
      account: account
    )
    vendas = find_or_create_user(
      email: 'vendas@gg2.com.br',
      name: 'Atendente Vendas GG2',
      role: :agent,
      account: account
    )
    sac = find_or_create_user(
      email: 'sac@gg2.com.br',
      name: 'Atendente SAC GG2',
      role: :agent,
      account: account
    )

    [admin, vendas, sac]
  end

  def find_or_create_user(email:, name:, role:, account:)
    user = User.from_email(email) || User.new(email: email)
    user.name = name
    user.password = DEFAULT_PASSWORD
    user.password_confirmation = DEFAULT_PASSWORD
    user.confirmed_at ||= Time.current
    user.save!

    account_user = AccountUser.find_or_initialize_by(account: account, user: user)
    account_user.role = role
    account_user.save!

    user
  end

  def setup_teams(account, vendas_agent, sac_agent)
    vendas_team = create_team_with_member(account, 'Equipe Vendas', 'Atendimento comercial e leads', vendas_agent)
    sac_team = create_team_with_member(account, 'Equipe SAC', 'Suporte ao cliente e pós-venda', sac_agent)
    vip_team = create_team_with_member(account, 'Equipe VIP', 'Atendimento de alta prioridade', vendas_agent)
    TeamMember.find_or_create_by!(team: vip_team, user: sac_agent)

    [vendas_team, sac_team, vip_team]
  end

  def create_team_with_member(account, name, description, user)
    team = account.teams.where('lower(name) = ?', name.downcase).first || account.teams.build(name: name)
    team.name = name
    team.description = description
    team.allow_auto_assign = true
    team.save!
    TeamMember.find_or_create_by!(team: team, user: user)
    team
  end

  def setup_inbox(account, users)
    channel = Channel::Whatsapp.find_by(phone_number: WHATSAPP_PHONE)
    unless channel
      channel = Channel::Whatsapp.new(account: account, phone_number: WHATSAPP_PHONE, provider: 'default')
      channel.save!(validate: false)
    end

    inbox = Inbox.find_or_initialize_by(account: account, channel: channel)
    inbox.name = 'WhatsApp Oficial GG2'
    inbox.working_hours_enabled = true
    inbox.out_of_office_message = 'Olá! Nosso horário de atendimento é de Segunda a Sexta, das 08:00 às 18:00.'
    inbox.save!

    users.each { |user| InboxMember.find_or_create_by!(inbox: inbox, user: user) }
    setup_working_hours(inbox, account)
    inbox
  end

  def setup_working_hours(inbox, account)
    (0..6).each do |day|
      wh = WorkingHour.find_or_initialize_by(inbox: inbox, account_id: account.id, day_of_week: day)
      if [0, 6].include?(day)
        wh.closed_all_day = true
        wh.open_all_day = false
      else
        wh.closed_all_day = false
        wh.open_all_day = false
        wh.open_hour = 8
        wh.open_minutes = 0
        wh.close_hour = 18
        wh.close_minutes = 0
      end
      wh.save!
    end
  end

  def setup_sample_flow(account)
    flow = Custom::Flow.find_or_initialize_by(account: account, name: 'Fluxo Geral de Atendimento GG2')
    flow.description = 'URA Comercial e Suporte com botões interativos e IA Bedrock'
    flow.status = :published
    flow.trigger_type = 'automation'
    flow.nodes = sample_nodes
    flow.edges = sample_edges
    flow.save!
    flow
  end

  def sample_nodes
    [welcome_node, vendas_node, sac_node, ai_node]
  end

  def welcome_node
    {
      id: 'node_welcome',
      type: 'interactive_buttons',
      data: {
        text: 'Olá! Seja bem-vindo à GG2. Como podemos te ajudar hoje?',
        buttons: [
          { id: 'btn_vendas', title: '🛍️ Quero Comprar' },
          { id: 'btn_sac', title: '🛠️ Suporte / SAC' },
          { id: 'btn_atendente', title: '👤 Falar com Atendente' }
        ]
      }
    }
  end

  def vendas_node
    {
      id: 'node_vendas',
      type: 'team_assignment',
      data: { team_name: 'Equipe Vendas', message: 'Perfeito! Estamos transferindo você para nosso time de Vendas.' }
    }
  end

  def sac_node
    {
      id: 'node_sac',
      type: 'team_assignment',
      data: { team_name: 'Equipe SAC', message: 'Entendido! Um de nossos especialistas de Suporte vai te atender.' }
    }
  end

  def ai_node
    {
      id: 'node_ai_fallback',
      type: 'ai_fallback',
      data: { model: 'amazon.nova-lite-v1:0', prompt: 'Você é o assistente virtual da GG2. Responda com clareza.' }
    }
  end

  def setup_custom_attributes(account)
    CustomAttributeDefinition.find_or_create_by!(
      account: account,
      attribute_key: 'etapa_fluxo',
      attribute_model: 'conversation_attribute'
    ) do |cad|
      cad.attribute_display_name = 'Etapa do Fluxo'
      cad.attribute_display_type = 'text'
      cad.attribute_description = 'Status do cliente na etapa atual do Flowbuilder'
    end

    CustomAttributeDefinition.find_or_create_by!(
      account: account,
      attribute_key: 'motivo_encerramento',
      attribute_model: 'conversation_attribute'
    ) do |cad|
      cad.attribute_display_name = 'Motivo de Encerramento'
      cad.attribute_display_type = 'text'
      cad.attribute_description = 'Motivo de conclusão registrado no encerramento da conversa'
    end
  end

  def setup_purchase_journey_flow(account)
    flow = Custom::Flow.find_or_initialize_by(account: account, name: '🛍️ Jornada de Compra Completa — E-commerce & URA')
    flow.description = 'Fluxo de vendas integrado ao Magento: IA Slot Filling, Consulta API, Try-Catch, Pix Copia-e-Cola e Kanban'
    flow.status = :published
    flow.trigger_type = 'automation'
    flow.trigger_config = { 'status_custom_attribute_key' => 'etapa_fluxo' }
    flow.nodes = purchase_journey_nodes
    flow.edges = purchase_journey_edges
    flow.save!
    flow
  end

  def purchase_journey_nodes
    [
      { id: 'start', type: 'start', position: { x: 400, y: 50 }, data: { label: 'Início da Conversa' } },
      {
        id: 'step_welcome',
        type: 'message',
        position: { x: 400, y: 150 },
        data: {
          label: 'Boas-vindas',
          step_status_value: 'inicio',
          text: 'Olá! Seja bem-vindo à nossa loja virtual. Sou a assistente de compras da GG2.'
        }
      },
      {
        id: 'step_ai_collector',
        type: 'ai_agent',
        position: { x: 400, y: 260 },
        data: {
          label: 'Identificação Inteligente (IA)',
          step_status_value: 'identificacao',
          extract_slots: true,
          required_fields: %w[cpf cep],
          completed_message: 'Perfeito! Dados localizados com sucesso. Consultando suas condições de compra...'
        }
      },
      {
        id: 'step_magento_lookup',
        type: 'async_api',
        position: { x: 400, y: 380 },
        data: {
          label: 'Consulta Cadastro Magento',
          step_status_value: 'consulta_cadastro',
          operation: 'magento_customer_lookup',
          wait_message: '⏳ Aguarde um instante enquanto consultamos seu cadastro e limite de crédito...'
        }
      },
      {
        id: 'step_try_catch',
        type: 'try_catch',
        position: { x: 720, y: 380 },
        data: {
          label: 'Tratamento de Oscilação de Rede',
          max_retries: 3,
          retry_message: 'Identificamos uma oscilação momentânea, tentando consultar seu cadastro novamente...'
        }
      },
      {
        id: 'step_condition_client',
        type: 'condition_router',
        position: { x: 400, y: 500 },
        data: {
          label: 'Cliente já cadastrado?',
          variable: 'customer_found',
          operator: 'equals',
          expected_value: 'true'
        }
      },
      {
        id: 'step_catalog',
        type: 'interactive_list',
        position: { x: 400, y: 620 },
        data: {
          label: 'Catálogo de Produtos',
          step_status_value: 'escolha_produtos',
          body: 'Selecione a categoria de produtos que você gostaria de adicionar ao seu pedido:',
          button_text: 'Ver Categorias',
          items: [
            { id: 'cat_resinas', title: 'Resinas & Dentística', description: 'Filtek Z350 XT, Single Bond 2' },
            { id: 'cat_descartaveis', title: 'Descartáveis & Luvas', description: 'Luvas Nitrílicas, Máscaras e Babadores' },
            { id: 'cat_moldagem', title: 'Moldagem & Prótese', description: 'Alginato Hydrogum, Silicones de Adição' }
          ]
        }
      },
      {
        id: 'step_quote_freight',
        type: 'async_api',
        position: { x: 400, y: 760 },
        data: {
          label: 'Cálculo de Frete & Cotação',
          step_status_value: 'cotacao_frete',
          operation: 'magento_create_quote',
          wait_message: '📦 Calculando o frete e aplicando descontos de tabela para o seu CEP...'
        }
      },
      {
        id: 'step_pay_choice',
        type: 'interactive_buttons',
        position: { x: 400, y: 880 },
        data: {
          label: 'Resumo e Forma de Pagamento',
          step_status_value: 'aguardando_pagamento',
          body: "📦 Resumo do Pedido:\n- 2x Resina Filtek Z350 XT A2 3M\n- Frete Sedex: R$ 15,00\nTotal: R$ 195,00 (ou R$ 185,25 no Pix)\n\nComo deseja pagar?",
          buttons: [
            { id: 'pay_pix', title: 'Pix (5% OFF)' },
            { id: 'pay_boleto', title: 'Boleto Bancário' },
            { id: 'pay_human', title: 'Falar com Vendedor' }
          ]
        }
      },
      {
        id: 'step_place_order',
        type: 'async_api',
        position: { x: 400, y: 1000 },
        data: {
          label: 'Gerar Pedido no Magento',
          step_status_value: 'gerando_pedido',
          operation: 'magento_place_order',
          wait_message: '🎉 Gerando seu pedido e chave Pix...'
        }
      },
      {
        id: 'step_deliver_pix',
        type: 'message',
        position: { x: 400, y: 1120 },
        data: {
          label: 'Entrega do Pix Copia-e-Cola',
          step_status_value: 'pix_enviado',
          text: "🎉 Pedido \#{{context.order_id}} gerado com sucesso no valor de R$ \#{{context.amount}}!\n\nCopie o código Pix abaixo para pagamento:\n\n\#{{context.pix_code}}\n\nApós o pagamento, o envio é imediato via Sedex!"
        }
      },
      {
        id: 'step_tag_labels',
        type: 'manage_labels',
        position: { x: 400, y: 1240 },
        data: {
          label: 'Etiquetar Cliente',
          target: 'conversation',
          action: 'add',
          labels: ['comprou-pix', 'cliente-ecommerce']
        }
      },
      {
        id: 'step_kanban',
        type: 'kanban_stage_change',
        position: { x: 400, y: 1350 },
        data: {
          label: 'Mover no Funil Comercial',
          stage_id: 'aguardando_pagamento',
          stage_name: 'Aguardando Pagamento'
        }
      },
      {
        id: 'step_finish',
        type: 'finish',
        position: { x: 400, y: 1460 },
        data: {
          label: 'Finalizar com Motivo',
          closure_attribute_key: 'motivo_encerramento',
          closure_reason: 'Venda Realizada com Sucesso (Pix)',
          farewell_message: 'Muito obrigado pela preferência! Qualquer dúvida, estamos à disposição.'
        }
      },
      {
        id: 'step_handoff',
        type: 'human_transfer',
        position: { x: 750, y: 880 },
        data: {
          label: 'Transferir para Vendedor',
          step_status_value: 'transbordo_humano',
          team_name: 'Equipe Vendas',
          transfer_message: 'Encaminhando seu contato para nosso consultor de vendas. Um momento...'
        }
      }
    ]
  end

  def purchase_journey_edges
    [
      { id: 'e1', source: 'start', target: 'step_welcome' },
      { id: 'e2', source: 'step_welcome', target: 'step_ai_collector' },
      { id: 'e3', source: 'step_ai_collector', target: 'step_magento_lookup', condition: { status: 'completed' } },
      { id: 'e3_h', source: 'step_ai_collector', target: 'step_handoff', condition: { status: 'handoff' } },
      { id: 'e4_ok', source: 'step_magento_lookup', target: 'step_condition_client', condition: { status: 'success' } },
      { id: 'e4_err', source: 'step_magento_lookup', target: 'step_try_catch', condition: { status: 'error' } },
      { id: 'e5_retry', source: 'step_try_catch', target: 'step_magento_lookup', condition: { status: 'try' } },
      { id: 'e5_catch', source: 'step_try_catch', target: 'step_handoff', condition: { status: 'catch' } },
      { id: 'e6_true', source: 'step_condition_client', target: 'step_catalog', condition: { status: 'true' } },
      { id: 'e6_false', source: 'step_condition_client', target: 'step_catalog', condition: { status: 'false' } },
      { id: 'e7', source: 'step_catalog', target: 'step_quote_freight' },
      { id: 'e8', source: 'step_quote_freight', target: 'step_pay_choice', condition: { status: 'success' } },
      { id: 'e9_pix', source: 'step_pay_choice', target: 'step_place_order', condition: { button_id: 'pay_pix' } },
      { id: 'e9_bol', source: 'step_pay_choice', target: 'step_place_order', condition: { button_id: 'pay_boleto' } },
      { id: 'e9_vend', source: 'step_pay_choice', target: 'step_handoff', condition: { button_id: 'pay_human' } },
      { id: 'e10', source: 'step_place_order', target: 'step_deliver_pix', condition: { status: 'success' } },
      { id: 'e11', source: 'step_deliver_pix', target: 'step_tag_labels' },
      { id: 'e12', source: 'step_tag_labels', target: 'step_kanban' },
      { id: 'e13', source: 'step_kanban', target: 'step_finish' }
    ]
  end

  def sample_edges
    [
      { id: 'edge_1', source: 'node_welcome', target: 'node_vendas', condition: { button_id: 'btn_vendas' } },
      { id: 'edge_2', source: 'node_welcome', target: 'node_sac', condition: { button_id: 'btn_sac' } },
      { id: 'edge_3', source: 'node_welcome', target: 'node_ai_fallback', condition: { button_id: 'btn_atendente' } }
    ]
  end
end
