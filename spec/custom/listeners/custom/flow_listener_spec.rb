# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::FlowListener, type: :service do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:flow) do
    Custom::Flow.create!(
      account: account,
      name: 'Fluxo Automação Teste',
      status: :published,
      trigger_type: 'automation',
      nodes: [
        {
          id: 'start',
          type: 'start',
          data: { label: 'Início' }
        },
        {
          id: 'msg_1',
          type: 'message',
          data: { content: 'Olá! Bem-vindo ao fluxo via automação.' }
        }
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'msg_1' }
      ]
    )
  end

  describe 'AutomationRule model extension' do
    let(:rule) { build(:automation_rule, account: account) }

    it 'includes trigger_flow in actions_attributes' do
      expect(rule.actions_attributes).to include('trigger_flow')
    end

    it 'validates automation rule with trigger_flow action without errors' do
      rule.actions = [{ 'action_name' => 'trigger_flow', 'action_params' => [flow.id] }]
      expect(rule).to be_valid
    end
  end

  describe 'ActionService#trigger_flow execution' do
    let(:rule) do
      create(
        :automation_rule,
        account: account,
        name: 'Disparar Fluxo WhatsApp',
        event_name: 'conversation_created',
        actions: [{ 'action_name' => 'trigger_flow', 'action_params' => [flow.id] }]
      )
    end
    let(:action_service) { AutomationRules::ActionService.new(rule, account, conversation) }

    it 'creates a new active Custom::FlowSession and executes the engine' do
      expect do
        action_service.perform
      end.to change(Custom::FlowSession, :count).by(1)

      session = Custom::FlowSession.last
      expect(session.conversation_id).to eq(conversation.id)
      expect(session.custom_flow_id).to eq(flow.id)
      expect(session.status).to eq('active')
      expect(session.current_node_id).to eq('msg_1')
    end

    it 'completes any existing active session before starting a new flow' do
      old_session = Custom::FlowSession.create!(
        account: account,
        custom_flow: flow,
        conversation: conversation,
        status: :active,
        current_node_id: 'old_node'
      )

      action_service.perform

      expect(old_session.reload.status).to eq('completed')
      expect(old_session.context['replaced_by_flow_id']).to eq(flow.id)

      new_session = Custom::FlowSession.where(status: :active).last
      expect(new_session.id).not_to eq(old_session.id)
      expect(new_session.current_node_id).to eq('msg_1')
    end

    it 'gracefully ignores if flow is unpublished or not found' do
      flow.update!(status: :draft)

      expect do
        action_service.perform
      end.not_to change(Custom::FlowSession, :count)
    end
  end

  describe 'Custom::FlowListener' do
    let(:listener) { described_class.instance }

    context 'when incoming message arrives with active flow session' do
      let!(:session) do
        Custom::FlowSession.create!(
          account: account,
          custom_flow: flow,
          conversation: conversation,
          status: :active,
          current_node_id: 'start'
        )
      end
      let(:message) do
        create(:message, account: account, conversation: conversation, message_type: :incoming, content: 'Quero comprar')
      end
      let(:event) { Events::Base.new('message.created', Time.current, message: message) }

      it 'enqueues ProcessFlowJob on :flows_processing queue' do
        expect(Custom::Flows::ProcessFlowJob).to receive(:perform_later).with(
          session.id,
          hash_including(content: 'Quero comprar', message_id: message.id)
        )

        listener.message_created(event)
      end

      it 'does not enqueue if conversation already has an assignee agent' do
        agent = create(:user, account: account)
        conversation.update!(assignee: agent)

        expect(Custom::Flows::ProcessFlowJob).not_to receive(:perform_later)

        listener.message_created(event)
      end
    end

    context 'when human agent sends manual outgoing message' do
      let!(:agent) { create(:user, account: account) }
      let!(:session) do
        Custom::FlowSession.create!(
          account: account,
          custom_flow: flow,
          conversation: conversation,
          status: :active,
          current_node_id: 'start'
        )
      end
      let(:message) do
        create(:message, account: account, conversation: conversation, message_type: :outgoing, sender: agent, content: 'Olá, sou o atendente')
      end
      let(:event) { Events::Base.new('message.created', Time.current, message: message) }

      it 'interrupts the active flow session' do
        listener.message_created(event)

        expect(session.reload.status).to eq('interrupted_by_human')
        expect(session.context['interrupted_at']).to be_present
      end
    end

    context 'when conversation is assigned to human agent' do
      let!(:agent) { create(:user, account: account) }
      let!(:session) do
        Custom::FlowSession.create!(
          account: account,
          custom_flow: flow,
          conversation: conversation,
          status: :active,
          current_node_id: 'start'
        )
      end

      it 'interrupts the flow session on assignment update' do
        conversation.update!(assignee: agent)
        event = Events::Base.new('conversation.updated', Time.current, conversation: conversation)

        listener.conversation_updated(event)

        expect(session.reload.status).to eq('interrupted_by_human')
      end
    end
  end
end
