# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Kanban Stages API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:board) { Custom::KanbanBoard.create!(account: account, name: 'Pipeline Vendas') }
  let!(:stage) { Custom::KanbanStage.create!(account: account, custom_kanban_board: board, name: 'Lead', slug: 'lead', position: 0) }

  describe 'DELETE /api/v1/accounts/:account_id/kanban_boards/:board_id/stages/:id' do
    context 'when stage has no cards' do
      it 'deletes the stage successfully' do
        delete "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/stages/#{stage.id}",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:no_content)
        expect(Custom::KanbanStage.find_by(id: stage.id)).to be_nil
      end
    end

    context 'when stage has linked cards' do
      before do
        Custom::KanbanCard.create!(
          account: account,
          custom_kanban_board: board,
          custom_kanban_stage: stage,
          contact: contact,
          title: 'Oportunidade Ativa',
          value: 100.0
        )
      end

      it 'blocks deletion and returns unprocessable_entity' do
        delete "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/stages/#{stage.id}",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to include('Não é possível excluir um estágio que possui oportunidades vinculadas')
        expect(Custom::KanbanStage.find_by(id: stage.id)).to be_present
      end
    end
  end
end
