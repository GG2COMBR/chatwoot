# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Kanban Boards API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:board) { Custom::KanbanBoard.create!(account: account, name: 'Funil Comercial GG2') }
  let!(:stage) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead', slug: 'lead') }

  describe 'GET /api/v1/accounts/:account_id/kanban_boards' do
    it 'returns list of boards for authenticated user' do
      get "/api/v1/accounts/#{account.id}/kanban_boards",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].size).to eq(1)
      expect(body['payload'].first['name']).to eq('Funil Comercial GG2')
      expect(body['payload'].first['stages'].first['name']).to eq('Lead')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/kanban_boards' do
    it 'creates new board with default stages when stages empty' do
      post "/api/v1/accounts/#{account.id}/kanban_boards",
           params: { board: { name: 'Novo Funil SAC' } },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['payload']['name']).to eq('Novo Funil SAC')
      expect(body['payload']['stages'].size).to eq(4)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/kanban_boards/:id' do
    it 'updates board attributes' do
      patch "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}",
            params: { board: { name: 'Funil Comercial Atualizado', status_custom_attribute_key: 'etapa_vendas' } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(board.reload.name).to eq('Funil Comercial Atualizado')
      expect(board.status_custom_attribute_key).to eq('etapa_vendas')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/kanban_boards/:id' do
    it 'destroys the board' do
      delete "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}",
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(Custom::KanbanBoard.find_by(id: board.id)).to be_nil
    end
  end
end
