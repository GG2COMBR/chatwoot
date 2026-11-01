# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::KanbanListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:board) do
    Custom::KanbanBoard.create!(
      account: account,
      name: 'Vendas',
      status_custom_attribute_key: 'crm_status'
    )
  end
  let!(:stage) do
    Custom::KanbanStage.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Negociação',
      slug: 'negociacao',
      position: 0
    )
  end

  describe '#conversation_updated' do
    it 'syncs conversation custom attributes to kanban' do
      conversation.custom_attributes = { 'crm_status' => 'Negociação' }
      conversation.save!

      event = Events::Base.new('conversation_updated', Time.zone.now, conversation: conversation)
      listener.conversation_updated(event)

      card = Custom::KanbanCard.find_by(conversation_id: conversation.id, custom_kanban_board_id: board.id)
      expect(card).to be_present
      expect(card.custom_kanban_stage_id).to eq(stage.id)
    end
  end
end
