# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Kanban::AttributeSyncService, type: :service do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:board) do
    Custom::KanbanBoard.create!(
      account: account,
      name: 'Vendas',
      status_custom_attribute_key: 'pipeline_status'
    )
  end
  let!(:stage_lead) do
    Custom::KanbanStage.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Lead',
      slug: 'lead',
      position: 0
    )
  end
  let!(:stage_proposta) do
    Custom::KanbanStage.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Proposta Enviada',
      slug: 'proposta_enviada',
      position: 1
    )
  end

  describe '#sync!' do
    context 'when conversation custom_attributes has mapped key' do
      it 'creates card in matching stage if card does not exist' do
        conversation.custom_attributes = { 'pipeline_status' => 'Proposta Enviada' }
        conversation.save!

        described_class.sync_conversation!(conversation)

        card = Custom::KanbanCard.find_by(conversation_id: conversation.id, custom_kanban_board_id: board.id)
        expect(card).to be_present
        expect(card.custom_kanban_stage_id).to eq(stage_proposta.id)
      end

      it 'moves existing card to matching stage' do
        card = Custom::KanbanCard.create!(
          account: account,
          custom_kanban_board: board,
          custom_kanban_stage: stage_lead,
          contact: contact,
          conversation: conversation,
          title: 'Card 1'
        )

        conversation.custom_attributes = { 'pipeline_status' => 'Proposta Enviada' }
        conversation.save!

        described_class.sync_conversation!(conversation)

        expect(card.reload.custom_kanban_stage_id).to eq(stage_proposta.id)
      end

      it 'does not update card if it is already in target stage' do
        card = Custom::KanbanCard.create!(
          account: account,
          custom_kanban_board: board,
          custom_kanban_stage: stage_proposta,
          contact: contact,
          conversation: conversation,
          title: 'Card 1'
        )

        expect(card).not_to receive(:update!)
        conversation.custom_attributes = { 'pipeline_status' => 'Proposta Enviada' }
        described_class.sync_conversation!(conversation)
      end
    end
  end
end
