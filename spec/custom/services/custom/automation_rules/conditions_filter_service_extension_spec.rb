# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::AutomationRules::ConditionsFilterServiceExtension do
  let(:account) { create(:account) }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Funil') }
  let(:stage) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead', slug: 'lead') }
  let(:conversation) { create(:conversation, account: account, custom_kanban_stage: stage) }
  let(:rule) do
    create(
      :automation_rule,
      account: account,
      event_name: 'conversation_updated',
      conditions: [
        {
          'attribute_key' => 'custom_kanban_stage_id',
          'filter_operator' => 'equal_to',
          'values' => [stage.id],
          'query_operator' => nil
        }
      ]
    )
  end

  it 'registers custom_kanban_stage_id in conversation filters and matches condition' do
    service = AutomationRules::ConditionsFilterService.new(rule, conversation)
    expect(service.perform).to be true
  end

  it 'returns false when conversation stage does not match condition' do
    other_stage = Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Outro', slug: 'outro')
    conversation.update!(custom_kanban_stage: other_stage)

    service = AutomationRules::ConditionsFilterService.new(rule, conversation)
    expect(service.perform).to be false
  end
end
