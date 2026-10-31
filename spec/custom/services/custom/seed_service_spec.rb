# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::SeedService do
  describe '.perform!' do
    it 'creates GG2 account and configured users' do
      result = described_class.perform!

      expect(result[:account]).to be_persisted
      expect(result[:account].name).to eq('GG2 Tecnologia')
      expect(result[:account].locale).to eq('pt_BR')
      expect(result[:admin].email).to eq('admin@gg2.com.br')
      expect(result[:admin].account_users.find_by(account: result[:account])).to be_administrator
    end

    it 'creates teams and WhatsApp inbox with working hours' do
      result = described_class.perform!

      team_names = result[:teams].map(&:name)
      expect(team_names).to include('equipe vendas', 'equipe sac', 'equipe vip')
      expect(result[:inbox].name).to eq('WhatsApp Oficial GG2')
      expect(result[:inbox].working_hours_enabled).to be true
      expect(result[:inbox].working_hours.count).to eq(7)
    end

    it 'publishes sample flow' do
      result = described_class.perform!

      expect(result[:flow]).to be_persisted
      expect(result[:flow].name).to eq('Fluxo Geral de Atendimento GG2')
      expect(result[:flow].status).to eq('published')
      expect(result[:flow].nodes.size).to be >= 4
    end

    it 'is completely idempotent on multiple runs' do
      first_result = described_class.perform!

      expect do
        second_result = described_class.perform!
        expect(second_result[:account].id).to eq(first_result[:account].id)
        expect(second_result[:flow].id).to eq(first_result[:flow].id)
      end.not_to change(Account, :count)
    end
  end
end
