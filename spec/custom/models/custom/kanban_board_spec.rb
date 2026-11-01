# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::KanbanBoard, type: :model do
  let(:account) { create(:account) }

  it 'creates a kanban board with valid attributes' do
    board = described_class.create!(
      account: account,
      name: 'Funil de Vendas',
      description: 'Funil comercial principal',
      position: 0
    )

    expect(board.persisted?).to be true
    expect(board.account).to eq(account)
    expect(board.name).to eq('Funil de Vendas')
  end

  it 'validates presence of name' do
    board = described_class.new(account: account, name: '')
    expect(board.valid?).to be false
    expect(board.errors[:name]).to be_present
  end

  it 'destroys associated stages when destroyed' do
    board = described_class.create!(account: account, name: 'Funil Teste')
    Custom::KanbanStage.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Lead',
      slug: 'lead'
    )

    expect { board.destroy! }.to change(Custom::KanbanStage, :count).by(-1)
  end
end
