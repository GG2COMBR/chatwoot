# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::ExecutionEngine do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:flow) do
    Custom::Flow.create!(
      account: account,
      name: 'Flow Test',
      status: :published,
      nodes: [
        {
          id: 'node_1',
          type: 'interactive_buttons',
          data: { text: 'Escolha uma opção' }
        },
        {
          id: 'node_vendas',
          type: 'team_assignment',
          data: { team_name: 'Equipe Vendas' }
        },
        {
          id: 'node_sac',
          type: 'team_assignment',
          data: { team_name: 'Equipe SAC' }
        },
        {
          id: 'node_ai',
          type: 'ai_fallback',
          data: { model: 'amazon.nova-lite-v1:0' }
        }
      ],
      edges: [
        { id: 'edge_1', source: 'node_1', target: 'node_vendas', condition: { button_id: 'btn_vendas' } },
        { id: 'edge_2', source: 'node_1', target: 'node_sac', condition: { value: 'sac' } },
        { id: 'edge_3', source: 'node_1', target: 'node_ai', condition: { default: true } }
      ]
    )
  end
  let(:conversation) { create(:conversation, account: account) }
  let(:session) { Custom::FlowSession.create!(account: account, custom_flow: flow, conversation: conversation, status: :active) }

  describe '.process!' do
    it 'starts flow on initial node when current_node_id is nil' do
      described_class.process!(session)

      expect(session.current_node_id).to eq('node_1')
      expect(session.context['last_prompt']).to eq('Escolha uma opção')
    end

    it 'transitions to node_vendas on button_id match' do
      session.update!(current_node_id: 'node_1')

      described_class.process!(session, button_id: 'btn_vendas')

      expect(session.current_node_id).to eq('node_vendas')
      expect(session.status).to eq('handoff')
    end

    it 'transitions to node_sac on text value match' do
      session.update!(current_node_id: 'node_1')

      described_class.process!(session, content: 'SAC')

      expect(session.current_node_id).to eq('node_sac')
      expect(session.status).to eq('handoff')
    end

    it 'falls back to default edge and dispatches ai_fallback response' do
      session.update!(current_node_id: 'node_1')

      allow(Custom::Ai::BedrockService).to receive(:chat).and_return(
        status: 'success',
        content: 'Olá! Sou a IA da GG2. Como posso ajudar?'
      )

      expect do
        described_class.process!(session, content: 'Quero tirar uma dúvida geral')
      end.to change { conversation.messages.count }.by(1)

      expect(session.current_node_id).to eq('node_ai')
      expect(session.context['ai_routed']).to be true
      expect(conversation.messages.last.content).to eq('Olá! Sou a IA da GG2. Como posso ajudar?')
    end

    it 'detects human attendant intent on ai node and transfers to human team immediately' do
      session.update!(current_node_id: 'node_1')
      expect(Custom::Ai::BedrockService).not_to receive(:chat)

      described_class.process!(session, content: 'Quero falar com um atendente agora')

      expect(session.current_node_id).to eq('node_ai')
      expect(session.status).to eq('handoff')
      expect(session.context['handoff_reason']).to eq('human_intent_detected')
    end

    it 'does not process when session is not active' do
      session.update!(status: :completed, current_node_id: 'node_1')

      described_class.process!(session, button_id: 'btn_vendas')

      expect(session.current_node_id).to eq('node_1')
      expect(session.status).to eq('completed')
    end

    it 'executes async_action node by creating wait message and enqueuing AsyncActionJob' do
      async_flow = Custom::Flow.create!(
        account: account,
        name: 'Async Flow',
        status: :published,
        nodes: [
          {
            id: 'node_async',
            type: 'async_action',
            data: { wait_message: '⏳ Aguarde...', type: 'mock' }
          }
        ],
        edges: []
      )
      async_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: async_flow,
        conversation: conversation,
        status: :active
      )

      expect(Custom::Flows::AsyncActionJob).to receive(:perform_later).with(
        async_session.id,
        'node_async',
        { 'wait_message' => '⏳ Aguarde...', 'type' => 'mock' }
      )

      expect do
        described_class.process!(async_session)
      end.to change { conversation.messages.count }.by(1)

      expect(conversation.messages.last.content).to eq('⏳ Aguarde...')
      expect(async_session.current_node_id).to eq('node_async')
    end

    it 'tracks retry counts on unmatched input and routes to escape path when max_retries reached' do
      escape_flow = Custom::Flow.create!(
        account: account,
        name: 'Retry Flow',
        status: :published,
        nodes: [
          {
            id: 'node_menu',
            type: 'interactive_buttons',
            data: { text: 'Menu', max_retries: 2, retry_message: 'Opção inválida, tente novamente' }
          },
          {
            id: 'node_escape',
            type: 'team_assignment',
            data: { team_name: 'Equipe SAC' }
          }
        ],
        edges: [
          { id: 'edge_esc', source: 'node_menu', target: 'node_escape', condition: { fallback: true } }
        ]
      )
      retry_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: escape_flow,
        conversation: conversation,
        status: :active,
        current_node_id: 'node_menu'
      )

      # Attempt 1: invalid input, retries becomes 1, re-prompts
      described_class.process!(retry_session, content: 'opcao_invalida_1')
      expect(retry_session.reload.context['retries']).to eq(1)
      expect(retry_session.current_node_id).to eq('node_menu')

      # Attempt 2: invalid input, reaches max_retries (2), routes to escape node
      described_class.process!(retry_session, content: 'opcao_invalida_2')
      expect(retry_session.reload.context['retries']).to eq(2)
      expect(retry_session.current_node_id).to eq('node_escape')
      expect(retry_session.status).to eq('handoff')
    end

    it 'resets retries counter to 0 upon successful edge transition' do
      session.update!(current_node_id: 'node_1', context: { 'retries' => 1 })

      described_class.process!(session, button_id: 'btn_vendas')

      expect(session.reload.current_node_id).to eq('node_vendas')
      expect(session.context['retries']).to eq(0)
    end
  end
end
