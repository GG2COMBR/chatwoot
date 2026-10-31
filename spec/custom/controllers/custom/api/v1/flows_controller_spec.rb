# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Flows API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:flow) do
    Custom::Flow.create!(
      account: account,
      name: 'Fluxo Comercial',
      description: 'Atendimento de Vendas',
      status: :draft,
      trigger_type: 'default',
      nodes: [
        { id: 'start', type: 'start', position: { x: 100, y: 100 } },
        { id: 'msg_1', type: 'message', data: { text: 'Olá!' }, position: { x: 100, y: 200 } }
      ],
      edges: [
        { id: 'e1', source: 'start', target: 'msg_1' }
      ]
    )
  end

  describe 'GET /api/v1/accounts/:account_id/custom_flows' do
    it 'returns unauthorized when not authenticated' do
      get "/api/v1/accounts/#{account.id}/custom_flows"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns forbidden for non-admin agent' do
      get "/api/v1/accounts/#{account.id}/custom_flows",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns list of flows for administrator' do
      get "/api/v1/accounts/#{account.id}/custom_flows",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['payload'].size).to eq(1)
      expect(body['payload'].first['name']).to eq('Fluxo Comercial')
      expect(body['payload'].first['nodes_count']).to eq(2)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/custom_flows/:id' do
    it 'returns detailed flow graph' do
      get "/api/v1/accounts/#{account.id}/custom_flows/#{flow.id}",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body['payload']
      expect(body['id']).to eq(flow.id)
      expect(body['nodes'].size).to eq(2)
      expect(body['edges'].size).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/custom_flows' do
    it 'creates a new draft flow' do
      post "/api/v1/accounts/#{account.id}/custom_flows",
           headers: admin.create_new_auth_token,
           params: {
             custom_flow: {
               name: 'Novo Fluxo SAC',
               description: 'Suporte e dúvidas',
               trigger_type: 'default',
               nodes: [{ id: 'start', type: 'start' }],
               edges: []
             }
           },
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body['payload']
      expect(body['name']).to eq('Novo Fluxo SAC')
      expect(body['status']).to eq('draft')
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/custom_flows/:id' do
    it 'updates flow attributes and nodes' do
      patch "/api/v1/accounts/#{account.id}/custom_flows/#{flow.id}",
            headers: admin.create_new_auth_token,
            params: {
              custom_flow: {
                name: 'Fluxo Comercial VIP'
              }
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(flow.reload.name).to eq('Fluxo Comercial VIP')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/custom_flows/:id/publish' do
    it 'publishes flow when graph has a start node' do
      post "/api/v1/accounts/#{account.id}/custom_flows/#{flow.id}/publish",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(flow.reload.status).to eq('published')
    end

    it 'returns unprocessable entity when graph is missing start node' do
      flow.update!(nodes: [{ id: 'node_1', type: 'message' }])

      post "/api/v1/accounts/#{account.id}/custom_flows/#{flow.id}/publish",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('nó inicial')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/custom_flows/:id/duplicate' do
    it 'duplicates flow as draft with copy suffix' do
      post "/api/v1/accounts/#{account.id}/custom_flows/#{flow.id}/duplicate",
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body['payload']
      expect(body['name']).to eq('Fluxo Comercial (Cópia)')
      expect(body['status']).to eq('draft')
      expect(Custom::Flow.where(account: account).count).to eq(2)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/custom_flows/:id' do
    it 'deletes the flow' do
      delete "/api/v1/accounts/#{account.id}/custom_flows/#{flow.id}",
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(Custom::Flow.find_by(id: flow.id)).to be_nil
    end
  end
end
