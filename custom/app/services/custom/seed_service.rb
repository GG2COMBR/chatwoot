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
    teams = setup_teams(account, vendas_agent, sac_agent)
    inbox = setup_inbox(account, [admin, vendas_agent, sac_agent])
    flow = setup_sample_flow(account)

    { account: account, admin: admin, teams: teams, inbox: inbox, flow: flow }
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
    flow.trigger_type = 'default'
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

  def sample_edges
    [
      { id: 'edge_1', source: 'node_welcome', target: 'node_vendas', condition: { button_id: 'btn_vendas' } },
      { id: 'edge_2', source: 'node_welcome', target: 'node_sac', condition: { button_id: 'btn_sac' } },
      { id: 'edge_3', source: 'node_welcome', target: 'node_ai_fallback', condition: { button_id: 'btn_atendente' } }
    ]
  end
end
