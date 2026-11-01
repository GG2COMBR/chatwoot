# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom::Conversation extension', type: :model do
  let(:account) { create(:account) }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Funil') }
  let(:stage) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead', slug: 'lead') }
  let(:conversation) { create(:conversation, account: account) }

  it 'associates conversation to a custom kanban stage' do
    conversation.update!(custom_kanban_stage: stage)
    expect(conversation.reload.custom_kanban_stage).to eq(stage)
    expect(conversation.custom_kanban_stage_id).to eq(stage.id)
  end

  it 'nullifies custom_kanban_stage_id when stage is destroyed' do
    conversation.update!(custom_kanban_stage: stage)
    stage.destroy!
    expect(conversation.reload.custom_kanban_stage_id).to be_nil
  end
end
