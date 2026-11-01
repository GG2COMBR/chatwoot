# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::KanbanCardNote do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Vendas') }
  let(:stage) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead', slug: 'lead') }
  let(:contact) { Contact.create!(account: account, name: 'Cliente Teste') }
  let(:user) { User.create!(name: 'Agente', email: 'agente@test.com', password: 'Password123!', password_confirmation: 'Password123!') }
  let(:card) do
    Custom::KanbanCard.create!(
      account: account,
      custom_kanban_board: board,
      custom_kanban_stage: stage,
      contact: contact,
      title: 'Oportunidade 1'
    )
  end

  it 'validates presence of content' do
    note = described_class.new(account: account, custom_kanban_card: card, user: user)
    expect(note).not_to be_valid
    expect(note.errors[:content]).to include("can't be blank")
  end

  it 'creates note associated to card and user' do
    note = described_class.create!(
      account: account,
      custom_kanban_card: card,
      user: user,
      content: 'Cliente solicitou desconto de 10% no Pix.'
    )

    expect(note).to be_persisted
    expect(card.custom_kanban_card_notes).to include(note)
  end
end
