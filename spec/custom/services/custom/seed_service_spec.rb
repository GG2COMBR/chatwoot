# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::SeedService do
  describe '.perform!' do
    before do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Channel::Whatsapp).to receive(:sync_templates).and_return(true)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'creates GG2 account and configured users' do
      result = described_class.perform!

      expect(result[:account]).to be_persisted
      expect(result[:account].name).to eq('GG2 Tecnologia')
      expect(result[:account].locale).to eq('pt_BR')
      expect(result[:admin].email).to eq('admin@gg2.com.br')
      expect(result[:admin].account_users.find_by(account: result[:account])).to be_administrator
    end

    it 'activates Enterprise plan and advanced features on account' do
      result = described_class.perform!
      account = result[:account]

      plan = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value
      expect(plan).to eq('enterprise')
      expect(account.feature_enabled?('sla')).to be true
      expect(account.feature_enabled?('automations')).to be true
      expect(account.feature_enabled?('custom_roles')).to be true
      expect(account.feature_enabled?('audit_logs')).to be true
    end

    it 'creates canonical kanban board and stages' do
      result = described_class.perform!

      expect(result[:kanban_board]).to be_persisted
      expect(result[:kanban_board].name).to eq('Funil de Vendas & Atendimento')

      stage_slugs = result[:kanban_stages].map(&:slug)
      expect(stage_slugs).to include('lead_qualificado', 'orcamento_enviado', 'aguardando_pix', 'concluido')
    end

    it 'creates teams and WhatsApp inbox with working hours' do
      result = described_class.perform!

      team_names = result[:teams].map(&:name)
      expect(team_names).to include('equipe vendas', 'equipe sac', 'equipe vip')
      expect(result[:inbox].name).to eq('WhatsApp Oficial GG2')
      expect(result[:inbox].working_hours_enabled).to be true
      expect(result[:inbox].working_hours.count).to eq(7)
    end

    it 'publishes sample flow and purchase journey flow' do
      result = described_class.perform!

      expect(result[:flow]).to be_persisted
      expect(result[:flow].name).to eq('Fluxo Geral de Atendimento GG2')
      expect(result[:flow].status).to eq('published')
      expect(result[:flow].nodes.size).to be >= 4

      expect(result[:purchase_flow]).to be_persisted
      expect(result[:purchase_flow].nodes.size).to be >= 10
      expect(Custom::KanbanCard.where(account: result[:account]).count).to eq(4)
    end

    it 'creates an active automation rule to trigger the flow on new conversations' do
      result = described_class.perform!

      rule = AutomationRule.find_by(account: result[:account], name: '🤖 Disparar Fluxo Geral de Atendimento GG2')
      expect(rule).to be_present
      expect(rule.active).to be true
      expect(rule.event_name).to eq('conversation_created')
      expect(rule.actions.first['action_name']).to eq('trigger_flow')
      expect(rule.actions.first['action_params']).to eq([result[:flow].id])
    end

    it 'is completely idempotent on multiple runs' do
      first_result = described_class.perform!

      expect do
        second_result = described_class.perform!
        expect(second_result[:account].id).to eq(first_result[:account].id)
        expect(second_result[:flow].id).to eq(first_result[:flow].id)
        expect(second_result[:kanban_board].id).to eq(first_result[:kanban_board].id)
      end.not_to change(Account, :count)
    end

    it 'supports clean minimal setup when with_demo is false' do
      Account.create!(name: 'Conta Limpa Dev')
      result = described_class.new.perform!(with_demo: false)

      expect(result[:with_demo]).to be false
      expect(result[:teams]).to be_empty
      expect(result[:inbox]).to be_nil
      expect(result[:flow]).to be_nil
      expect(result[:purchase_flow]).to be_nil
      expect(Custom::KanbanCard.where(account: result[:account]).count).to eq(0)
      expect(result[:admin].email).to eq('admin@gg2.com.br')
    end
  end
end
