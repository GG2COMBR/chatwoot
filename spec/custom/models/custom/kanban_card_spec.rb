# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::KanbanCard do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Vendas') }
  let(:stage) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead', slug: 'lead') }
  let(:contact) { Contact.create!(account: account, name: 'Cliente Teste') }

  it 'validates presence of title' do
    card = described_class.new(account: account, custom_kanban_board: board, custom_kanban_stage: stage, contact: contact)
    expect(card).not_to be_valid
    expect(card.errors[:title]).to include("can't be blank")
  end

  it 'creates card with default open status and medium priority' do
    card = described_class.create!(
      account: account,
      custom_kanban_board: board,
      custom_kanban_stage: stage,
      contact: contact,
      title: 'Oportunidade 1'
    )

    expect(card.status).to eq('open')
    expect(card.priority).to eq('medium')
    expect(card.value).to eq(0.0)
    expect(card.stage_entered_at).to be_present
  end

  it 'tracks won_lost_at timestamp on won/lost status changes' do
    card = described_class.create!(
      account: account,
      custom_kanban_board: board,
      custom_kanban_stage: stage,
      contact: contact,
      title: 'Oportunidade 1'
    )

    expect(card.won_lost_at).to be_nil
    card.update!(status: :won)
    expect(card.won_lost_at).to be_present

    card.update!(status: :open)
    expect(card.won_lost_at).to be_nil
  end

  it 'updates stage_entered_at when stage changes' do
    stage2 = Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Negociação', slug: 'negociacao')
    card = described_class.create!(
      account: account,
      custom_kanban_board: board,
      custom_kanban_stage: stage,
      contact: contact,
      title: 'Oportunidade 1'
    )

    initial_time = card.stage_entered_at
    card.update!(custom_kanban_stage: stage2)
    expect(card.stage_entered_at).to be >= initial_time
  end
end
