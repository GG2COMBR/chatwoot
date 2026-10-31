# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Kanban::SyncService do
  let(:account) { Account.create!(name: 'Kanban Account') }
  let(:conversation) { create(:conversation, account: account) }

  describe '.handle_card_movement' do
    context 'when no flow is configured for the target stage' do
      it 'updates stage without triggering a flow' do
        result = described_class.handle_card_movement(conversation, 'stage_lead', stage_name: 'Novo Lead')

        expect(result[:status]).to eq('no_trigger')
        expect(result[:stage_id]).to eq('stage_lead')
        expect(conversation.reload.custom_attributes['kanban_stage_id']).to eq('stage_lead')
      end
    end

    context 'when a published flow is linked to the target stage' do
      let!(:flow) do
        Custom::Flow.create!(
          account: account,
          name: 'Payment Reminder Flow',
          status: :published,
          trigger_type: 'kanban_stage_entered',
          trigger_config: { 'stage_id' => 'waiting_payment' },
          nodes: [
            { id: 'start', type: 'start' },
            { id: 'msg_1', type: 'message', data: { text: 'Aguardando pagamento' } }
          ],
          edges: [
            { source: 'start', target: 'msg_1' }
          ]
        )
      end

      it 'creates and starts a new flow session for the conversation' do
        result = described_class.handle_card_movement(conversation, 'waiting_payment', stage_name: 'Aguardando Pagamento')

        expect(result[:status]).to eq('triggered')
        expect(result[:flow_id]).to eq(flow.id)

        session = Custom::FlowSession.find(result[:session_id])
        expect(session.conversation_id).to eq(conversation.id)
        expect(session.status).to eq('active')
        expect(session.context['trigger']).to eq('kanban_card_movement')
        expect(session.context['stage_id']).to eq('waiting_payment')
      end

      it 'completes previous active session when triggering new flow' do
        old_session = Custom::FlowSession.create!(
          account: account,
          custom_flow: flow,
          conversation: conversation,
          status: :active
        )

        described_class.handle_card_movement(conversation, 'waiting_payment')

        expect(old_session.reload.status).to eq('completed')
      end
    end

    context 'when matching flow is in draft status' do
      before do
        Custom::Flow.create!(
          account: account,
          name: 'Draft Flow',
          status: :draft,
          trigger_type: 'kanban_stage_entered',
          trigger_config: { 'stage_id' => 'in_draft' }
        )
      end

      it 'does not trigger draft flow' do
        result = described_class.handle_card_movement(conversation, 'in_draft')

        expect(result[:status]).to eq('no_trigger')
      end
    end
  end
end
