# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Canned Responses Team Visibility API', type: :request do
  let(:account) { create(:account) }
  let(:team_vendas) { create(:team, account: account, name: 'Vendas') }
  let(:team_sac) { create(:team, account: account, name: 'SAC') }

  let(:agent_vendas) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  let!(:cr_geral) { create(:canned_response, account: account, short_code: 'geral', content: 'Olá, como posso ajudar?') }
  let!(:cr_venda) do
    cr = create(:canned_response, account: account, short_code: 'venda', content: 'Oferta especial de vendas!')
    cr.sync_teams!([team_vendas.id])
    cr
  end
  let!(:cr_sac) do
    cr = create(:canned_response, account: account, short_code: 'sac', content: 'Atendimento de suporte SAC')
    cr.sync_teams!([team_sac.id])
    cr
  end

  before do
    create(:team_member, team: team_vendas, user: agent_vendas)
  end

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    it 'permite que atendente de Vendas veja apenas respostas públicas e do seu time' do
      get "/api/v1/accounts/#{account.id}/canned_responses",
          headers: agent_vendas.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      short_codes = response.parsed_body.pluck('short_code')
      expect(short_codes).to include(cr_geral.short_code, cr_venda.short_code)
      expect(short_codes).not_to include(cr_sac.short_code)
    end

    it 'permite que o administrador veja todas as respostas da conta' do
      get "/api/v1/accounts/#{account.id}/canned_responses",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      short_codes = response.parsed_body.pluck('short_code')
      expect(short_codes).to contain_exactly(cr_geral.short_code, cr_venda.short_code, cr_sac.short_code)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses com team_ids' do
    it 'cria resposta pronta restrita ao time SAC' do
      post "/api/v1/accounts/#{account.id}/canned_responses",
           params: {
             canned_response: {
               short_code: 'garantia',
               content: 'Termos de garantia SAC',
               team_ids: [team_sac.id]
             }
           },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      created_cr = CannedResponse.find(response.parsed_body['id'])
      expect(created_cr.teams).to contain_exactly(team_sac)
      expect(response.parsed_body['team_ids']).to eq([team_sac.id])
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/canned_responses/{id} com team_ids' do
    it 'atualiza visibilidade da resposta pronta para pública quando team_ids é vazio' do
      patch "/api/v1/accounts/#{account.id}/canned_responses/#{cr_venda.id}",
            params: {
              canned_response: {
                team_ids: []
              }
            },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      cr_venda.reload
      expect(cr_venda.teams).to be_empty
    end
  end
end
