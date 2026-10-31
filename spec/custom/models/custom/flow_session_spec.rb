# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::FlowSession, type: :model do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:flow) do
    Custom::Flow.create!(
      account: account,
      name: 'Fluxo SAC e Pedidos',
      status: :published,
      nodes: [{ id: 'node_1', type: 'message', data: { text: 'Boas-vindas ao SAC' } }],
      edges: [{ id: 'edge_1', source: 'node_1', target: 'node_2' }]
    )
  end

  let(:session) do
    described_class.new(
      account: account,
      custom_flow: flow,
      conversation: conversation,
      status: :active
    )
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(session).to be_valid
    end

    it 'requires account, custom_flow, and conversation' do
      invalid_session = described_class.new
      expect(invalid_session).not_to be_valid
      expect(invalid_session.errors[:account]).to be_present
      expect(invalid_session.errors[:custom_flow]).to be_present
      expect(invalid_session.errors[:conversation]).to be_present
    end
  end

  describe 'enums' do
    it 'supports all defined lifecycle statuses' do
      expect(described_class.statuses).to eq({
                                               'active' => 0,
                                               'completed' => 1,
                                               'handoff' => 2,
                                               'interrupted_by_human' => 3,
                                               'timed_out' => 4,
                                               'failed' => 5
                                             })
    end
  end

  describe 'snapshot freezing on create' do
    it 'automatically freezes flow_snapshot from flow definition upon creation' do
      session.save!

      expect(session.flow_snapshot).to be_present
      expect(session.flow_snapshot['flow_id']).to eq(flow.id)
      expect(session.flow_snapshot['nodes']).to eq([{ 'id' => 'node_1', 'type' => 'message', 'data' => { 'text' => 'Boas-vindas ao SAC' } }])
      expect(session.flow_snapshot['snapshot_taken_at']).to be_present
    end

    it 'preserves original snapshot even if parent flow definition changes later' do
      session.save!

      # Simula alteração do fluxo pelo gestor enquanto sessão está em andamento
      flow.update!(nodes: [{ id: 'node_2', type: 'message', data: { text: 'Novo menu alterado' } }])

      session.reload
      expect(session.flow_snapshot['nodes']).to eq([{ 'id' => 'node_1', 'type' => 'message', 'data' => { 'text' => 'Boas-vindas ao SAC' } }])
    end
  end

  describe '#update_context' do
    it 'merges new keys into context JSONB cleanly' do
      session.context = { 'cpf' => '12345678900' }
      session.save!

      session.update_context(nome: 'Maria Silva', tier: 'VIP')

      session.reload
      expect(session.context).to eq({
                                      'cpf' => '12345678900',
                                      'nome' => 'Maria Silva',
                                      'tier' => 'VIP'
                                    })
    end
  end
end
