# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::KanbanStage, type: :model do
  let(:account) { create(:account) }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Funil Comercial') }

  it 'creates a stage with valid attributes' do
    stage = described_class.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Proposta Enviada',
      slug: 'proposta_enviada',
      color: '#F59E0B'
    )

    expect(stage.persisted?).to be true
    expect(stage.custom_kanban_board).to eq(board)
    expect(stage.slug).to eq('proposta_enviada')
  end

  it 'validates presence of name and slug' do
    stage = described_class.new(account: account, custom_kanban_board: board)
    expect(stage.valid?).to be false
    expect(stage.errors[:name]).to be_present
    expect(stage.errors[:slug]).to be_present
  end

  it 'enforces uniqueness of slug within the same board' do
    described_class.create!(
      account: account,
      custom_kanban_board: board,
      name: 'Etapa 1',
      slug: 'etapa_1'
    )

    duplicate = described_class.new(
      account: account,
      custom_kanban_board: board,
      name: 'Etapa 1 Duplicada',
      slug: 'etapa_1'
    )

    expect(duplicate.valid?).to be false
    expect(duplicate.errors[:slug]).to be_present
  end
end
