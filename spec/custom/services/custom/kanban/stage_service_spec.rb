# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Kanban::StageService do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:flow) { Custom::Flow.create!(account: account, name: 'Kanban Flow', status: :published) }
  let(:conversation) { create(:conversation, account: account) }
  let(:session) { Custom::FlowSession.create!(account: account, custom_flow: flow, conversation: conversation, status: :active) }

  describe '.transition!' do
    it 'updates conversation custom_attributes with new stage information' do
      result = described_class.transition!(conversation, session, 'stage_qualified', 'Lead Qualificado')

      expect(result[:status]).to eq('success')
      expect(result[:stage_id]).to eq('stage_qualified')
      expect(result[:stage_name]).to eq('Lead Qualificado')

      attrs = conversation.reload.custom_attributes
      expect(attrs['kanban_stage_id']).to eq('stage_qualified')
      expect(attrs['kanban_stage_name']).to eq('Lead Qualificado')
      expect(attrs['kanban_stage_updated_at']).to be_present
    end

    it 'appends transition into session context stage_history' do
      described_class.transition!(conversation, session, 'stage_1', 'Primeiro Contato')
      described_class.transition!(conversation, session, 'stage_2', 'Proposta Enviada')

      session.reload
      expect(session.context['current_kanban_stage_id']).to eq('stage_2')
      expect(session.context['current_kanban_stage_name']).to eq('Proposta Enviada')

      history = session.context['stage_history']
      expect(history.size).to eq(2)
      expect(history.first['stage_id']).to eq('stage_1')
      expect(history.last['stage_id']).to eq('stage_2')
    end

    it 'defaults stage_name to humanized stage_id when not provided' do
      result = described_class.transition!(conversation, session, 'waiting_payment')

      expect(result[:stage_name]).to eq('Waiting payment')
    end

    it 'broadcasts kanban.stage_changed event via ActionCable' do
      allow(ActionCable.server).to receive(:broadcast)

      described_class.transition!(conversation, session, 'stage_demo', 'Demonstração Agendada')

      expect(ActionCable.server).to have_received(:broadcast).with(
        "account_#{account.id}_kanban",
        hash_including(
          event: 'kanban.stage_changed',
          data: hash_including(
            account_id: account.id,
            conversation_id: conversation.id,
            stage_id: 'stage_demo',
            stage_name: 'Demonstração Agendada'
          )
        )
      )
    end
  end
end
