# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Kanban Cards API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Vendas') }
  let(:stage1) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead', slug: 'lead') }
  let(:stage2) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Ganhos', slug: 'ganhos') }
  let(:contact) { create(:contact, account: account) }
  let!(:card) do
    Custom::KanbanCard.create!(
      account: account,
      custom_kanban_board: board,
      custom_kanban_stage: stage1,
      contact: contact,
      title: 'Negócio 1',
      value: 500.0
    )
  end

  describe 'GET /api/v1/accounts/:account_id/kanban_boards/:board_id/cards' do
    it 'lists cards belonging to the board' do
      get "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cards",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].size).to eq(1)
      expect(body['payload'].first['title']).to eq('Negócio 1')
      expect(body['payload'].first['value']).to eq(500.0)
    end

    it 'filters old completed cards based on completed_days window' do
      Custom::KanbanCard.create!(
        account: account,
        custom_kanban_board: board,
        custom_kanban_stage: stage2,
        contact: contact,
        title: 'Negócio Antigo Ganho',
        value: 1000.0,
        status: :won,
        won_lost_at: 30.days.ago
      )

      # Janela padrão de 14 dias: não inclui o card antigo
      get "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cards?completed_days=14",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      titles = response.parsed_body['payload'].map { |c| c['title'] }
      expect(titles).to include('Negócio 1')
      expect(titles).not_to include('Negócio Antigo Ganho')

      # Janela com completed_days=all: inclui o card histórico
      get "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cards?completed_days=all",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      titles_all = response.parsed_body['payload'].map { |c| c['title'] }
      expect(titles_all).to include('Negócio Antigo Ganho')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/kanban_boards/:board_id/cards' do
    it 'creates a new card' do
      post "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cards",
           params: {
             card: {
               custom_kanban_stage_id: stage1.id,
               contact_id: contact.id,
               title: 'Oportunidade Nova',
               value: 1250.0,
               priority: 'high'
             }
           },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['payload']['title']).to eq('Oportunidade Nova')
      expect(body['payload']['priority']).to eq('high')
      expect(body['payload']['value']).to eq(1250.0)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/kanban_boards/:board_id/cards/:id/move' do
    it 'moves card to another stage' do
      post "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cards/#{card.id}/move",
           params: { stage_id: stage2.id, position: 1 },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(card.reload.custom_kanban_stage_id).to eq(stage2.id)
      expect(card.position).to eq(1)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/kanban_boards/:board_id/cards/:id' do
    it 'destroys the card' do
      delete "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cards/#{card.id}",
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(Custom::KanbanCard.find_by(id: card.id)).to be_nil
    end
  end
end
