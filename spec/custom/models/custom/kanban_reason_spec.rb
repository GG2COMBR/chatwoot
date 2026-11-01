# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::KanbanReason do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Vendas') }

  it 'validates presence of name and valid reason_type' do
    reason = described_class.new(account: account, custom_kanban_board: board, reason_type: 'invalid')
    expect(reason).not_to be_valid
    expect(reason.errors[:name]).to include("can't be blank")
    expect(reason.errors[:reason_type]).to include('is not included in the list')
  end

  it 'creates won and lost reasons' do
    won_reason = described_class.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Melhor Preço',
      reason_type: 'won'
    )
    lost_reason = described_class.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Optou pelo Concorrente',
      reason_type: 'lost'
    )

    expect(won_reason).to be_persisted
    expect(lost_reason).to be_persisted
  end
end
