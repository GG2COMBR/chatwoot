# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::ScheduleEvaluatorService do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:contact) { create(:contact, account: account, name: 'Juliana Costa') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, status: :pending) }
  let(:team) { Team.create!(account: account, name: 'Equipe Vendas') }

  let(:weekly_config) do
    {
      timezone: 'America/Sao_Paulo',
      weekly_schedule: {
        'monday' => { open: '08:00', close: '18:00' },
        'tuesday' => { open: '08:00', close: '18:00' },
        'wednesday' => { open: '08:00', close: '18:00' },
        'thursday' => { open: '08:00', close: '18:00' },
        'friday' => { open: '08:00', close: '18:00' },
        'saturday' => { closed: true },
        'sunday' => { closed: true }
      },
      out_of_office_message: 'Olá {{contact.name}}! O time {{team.name}} atende em horário comercial.'
    }
  end

  describe '.open_now?' do
    it 'returns true during business hours on weekday' do
      wednesday_afternoon = Time.zone.parse('2026-10-28 14:00:00 -03:00')
      expect(described_class.open_now?(weekly_config, at: wednesday_afternoon)).to be true
    end

    it 'returns false after hours on weekday' do
      wednesday_night = Time.zone.parse('2026-10-28 21:00:00 -03:00')
      expect(described_class.open_now?(weekly_config, at: wednesday_night)).to be false
    end

    it 'returns false on closed weekend day' do
      sunday = Time.zone.parse('2026-11-01 10:00:00 -03:00')
      expect(described_class.open_now?(weekly_config, at: sunday)).to be false
    end
  end

  describe '.route_and_handoff!' do
    it 'assigns team and sets status to open when inside business hours' do
      wednesday_afternoon = Time.zone.parse('2026-10-28 14:00:00 -03:00')
      evaluator = described_class.new(weekly_config, at: wednesday_afternoon)

      result = evaluator.route_and_handoff!(conversation, team)

      expect(result[:open]).to be true
      expect(result[:status]).to eq(:open)
      expect(conversation.reload.team).to eq(team)
      expect(conversation.status).to eq('open')
      expect(conversation.messages.count).to eq(0)
    end

    it 'assigns team, keeps pending and sends out of office message when closed' do
      sunday = Time.zone.parse('2026-11-01 10:00:00 -03:00')
      evaluator = described_class.new(weekly_config, at: sunday)

      result = evaluator.route_and_handoff!(conversation, team)

      expect(result[:open]).to be false
      expect(result[:status]).to eq(:pending)
      expect(conversation.reload.team).to eq(team)
      expect(conversation.status).to eq('pending')

      last_message = conversation.messages.last
      expect(last_message).to be_present
      expect(last_message.content).to eq('Olá Juliana Costa! O time Equipe Vendas atende em horário comercial.')
    end
  end

  describe '.interpolate_message' do
    it 'interpolates contact and team names correctly' do
      template = 'Oi {{contact.name}}, você está falando com {{team.name}}.'
      result = described_class.interpolate_message(template, conversation, team)

      expect(result).to eq('Oi Juliana Costa, você está falando com Equipe Vendas.')
    end
  end
end
