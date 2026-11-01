# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Kanban::StageService do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:board) do
    Custom::KanbanBoard.create!(
      account: account,
      name: 'Funil Comercial',
      status_custom_attribute_key: 'etapa_comercial'
    )
  end
  let!(:kanban_stage) do
    Custom::KanbanStage.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Proposta Enviada',
      slug: 'proposta_enviada'
    )
  end
  let(:flow) { Custom::Flow.create!(account: account, name: 'Kanban Flow', status: :published) }
  let(:conversation) { create(:conversation, account: account) }
  let(:session) { Custom::FlowSession.create!(account: account, custom_flow: flow, conversation: conversation, status: :active) }

  describe '.transition!' do
    it 'syncs configured status_custom_attribute_key when present on the board' do
      result = described_class.transition!(conversation, session, 'proposta_enviada')

      expect(result[:status]).to eq('success')
      expect(result[:kanban_stage_id]).to eq(kanban_stage.id)
      expect(result[:stage_name]).to eq('Proposta Enviada')

      conversation.reload
      expect(conversation.custom_kanban_stage_id).to eq(kanban_stage.id)
      expect(conversation.custom_attributes['etapa_comercial']).to eq('Proposta Enviada')
      # Confirma que chaves legadas e ad-hoc não existem
      expect(conversation.custom_attributes['kanban_stage_id']).to be_nil
      expect(conversation.custom_attributes['kanban_stage_name']).to be_nil
    end

    it 'does not modify custom_attributes when board has no status_custom_attribute_key' do
      board.update!(status_custom_attribute_key: nil)
      conversation.update!(custom_attributes: {})

      result = described_class.transition!(conversation, session, 'proposta_enviada')

      expect(result[:status]).to eq('success')
      conversation.reload
      expect(conversation.custom_kanban_stage_id).to eq(kanban_stage.id)
      expect(conversation.custom_attributes).to be_empty
    end

    it 'resolves stage by numeric ID' do
      result = described_class.transition!(conversation, session, kanban_stage.id.to_s)

      expect(result[:status]).to eq('success')
      expect(result[:kanban_stage_id]).to eq(kanban_stage.id)
      expect(conversation.reload.custom_kanban_stage_id).to eq(kanban_stage.id)
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

    it 'broadcasts kanban.stage_changed event via ActionCable' do
      allow(ActionCable.server).to receive(:broadcast)

      described_class.transition!(conversation, session, 'proposta_enviada')

      expect(ActionCable.server).to have_received(:broadcast).with(
        "account_#{account.id}_kanban",
        hash_including(
          event: 'kanban.stage_changed',
          data: hash_including(
            account_id: account.id,
            conversation_id: conversation.id,
            kanban_stage_id: kanban_stage.id,
            stage_name: 'Proposta Enviada'
          )
        )
      )
    end

    it 'calculates dwell time in previous stage upon transition' do
      t0 = Time.zone.parse('2026-10-31 10:00:00 UTC')
      t1 = Time.zone.parse('2026-10-31 10:15:30 UTC')

      travel_to t0 do
        described_class.transition!(conversation, session, 'stage_initial', 'Novo Lead')
      end

      travel_to t1 do
        result = described_class.transition!(conversation, session, kanban_stage.id.to_s)
        expect(result[:dwell_time][:seconds]).to eq(930)
        expect(result[:dwell_time][:minutes]).to eq(15.5)

        session.reload
        first_entry = session.context['stage_history'].first
        expect(first_entry['dwell_time_seconds']).to eq(930)
        expect(first_entry['dwell_time_minutes']).to eq(15.5)
        expect(first_entry['exited_at']).to eq(t1.iso8601)
      end
    end
  end
end
