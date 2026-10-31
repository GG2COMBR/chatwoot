# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::EligibilityService do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let!(:flow) { Custom::Flow.create!(account: account, name: 'Flow 1', status: :published) }
  let(:conversation) { create(:conversation, account: account, status: :pending) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe '.eligible?' do
    it 'returns true for pending unassigned conversation with published flow' do
      expect(described_class.eligible?(conversation)).to be true
    end

    it 'returns false if conversation has an assigned human agent' do
      conversation.update!(assignee: agent)
      expect(described_class.eligible?(conversation)).to be false
    end

    it 'returns false if conversation is currently open' do
      conversation.update!(status: :open)
      expect(described_class.eligible?(conversation)).to be false
    end

    it 'returns false if account has no published flows' do
      flow.update!(status: :draft)
      expect(described_class.eligible?(conversation)).to be false
    end

    it 'validates message parameters when message is provided' do
      incoming_msg = build(:message, conversation: conversation, account: account, message_type: :incoming, private: false)
      outgoing_msg = build(:message, conversation: conversation, account: account, message_type: :outgoing, private: false)
      private_msg = build(:message, conversation: conversation, account: account, message_type: :incoming, private: true)

      expect(described_class.eligible?(conversation, incoming_msg)).to be true
      expect(described_class.eligible?(conversation, outgoing_msg)).to be false
      expect(described_class.eligible?(conversation, private_msg)).to be false
    end
  end

  describe '.handle_human_interruption and .handle_human_message' do
    let!(:active_session) do
      Custom::FlowSession.create!(
        account: account,
        custom_flow: flow,
        conversation: conversation,
        status: :active,
        context: { 'step' => 1 }
      )
    end

    it 'cancels active session with interrupted_by_human and sets interrupted_at' do
      interrupted = described_class.handle_human_interruption(conversation)
      expect(interrupted).to be true

      active_session.reload
      expect(active_session.status).to eq('interrupted_by_human')
      expect(active_session.context['interrupted_at']).to be_present
      expect(active_session.context['step']).to eq(1)
    end

    it 'triggers interruption when a human agent sends a public message' do
      agent_message = build(
        :message,
        conversation: conversation,
        account: account,
        sender: agent,
        message_type: :outgoing,
        private: false
      )

      interrupted = described_class.handle_human_message(agent_message)
      expect(interrupted).to be true

      active_session.reload
      expect(active_session.status).to eq('interrupted_by_human')
    end

    it 'ignores private notes sent by human agent' do
      private_note = build(
        :message,
        conversation: conversation,
        account: account,
        sender: agent,
        message_type: :outgoing,
        private: true
      )

      interrupted = described_class.handle_human_message(private_note)
      expect(interrupted).to be false

      active_session.reload
      expect(active_session.status).to eq('active')
    end
  end

  describe '.ensure_pending_state_on_reopen' do
    it 'resets resolved conversation to pending when reopened by customer' do
      conversation.update!(status: :resolved)
      changed = described_class.ensure_pending_state_on_reopen(conversation)

      expect(changed).to be true
      expect(conversation.reload.status).to eq('pending')
    end

    it 'resets snoozed conversation to pending when reopened by customer' do
      conversation.update!(status: :snoozed)
      changed = described_class.ensure_pending_state_on_reopen(conversation)

      expect(changed).to be true
      expect(conversation.reload.status).to eq('pending')
    end

    it 'does not modify conversation if already assigned to an agent' do
      conversation.update!(status: :resolved, assignee: agent)
      changed = described_class.ensure_pending_state_on_reopen(conversation)

      expect(changed).to be false
      expect(conversation.reload.status).to eq('resolved')
    end
  end
end
