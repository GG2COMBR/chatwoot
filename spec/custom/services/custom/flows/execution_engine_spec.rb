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

    it 'falls back to default edge when input does not match specific conditions' do
      session.update!(current_node_id: 'node_1')

      described_class.process!(session, content: 'Quero tirar uma dúvida geral')

      expect(session.current_node_id).to eq('node_ai')
      expect(session.context['ai_routed']).to be true
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
  end
end
