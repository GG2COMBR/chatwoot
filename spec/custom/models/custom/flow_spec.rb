# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flow, type: :model do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:flow) do
    described_class.new(
      account: account,
      name: 'Fluxo Comercial de Teste',
      description: 'URA de Vendas e Qualificação',
      status: :published,
      nodes: [{ id: '1', type: 'message', data: { text: 'Olá!' } }],
      edges: []
    )
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(flow).to be_valid
    end

    it 'requires a name' do
      flow.name = nil
      expect(flow).not_to be_valid
      expect(flow.errors[:name]).to include("can't be blank")
    end

    it 'requires an account' do
      flow.account = nil
      expect(flow).not_to be_valid
      expect(flow.errors[:account]).to be_present
    end
  end

  describe 'enums' do
    it 'supports draft, published, and archived statuses' do
      expect(described_class.statuses).to eq({ 'draft' => 0, 'published' => 1, 'archived' => 2 })
    end
  end

  describe 'scopes' do
    it 'filters flows by published and draft' do
      published_flow = described_class.create!(account: account, name: 'Flow 1', status: :published)
      draft_flow = described_class.create!(account: account, name: 'Flow 2', status: :draft)

      expect(described_class.published).to include(published_flow)
      expect(described_class.published).not_to include(draft_flow)
      expect(described_class.draft).to include(draft_flow)
    end
  end

  describe 'associations' do
    it 'destroys associated flow sessions when flow is deleted' do
      flow.save!
      conversation = create(:conversation, account: account)

      session = flow.custom_flow_sessions.create!(
        account: account,
        conversation: conversation,
        status: :active
      )

      expect { flow.destroy }.to change(Custom::FlowSession, :count).by(-1)
      expect(Custom::FlowSession.exists?(session.id)).to be false
    end
  end
end
