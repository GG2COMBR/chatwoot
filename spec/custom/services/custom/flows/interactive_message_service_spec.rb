# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::InteractiveMessageService do
  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:whatsapp_channel) do
    c = Channel::Whatsapp.new(account: account, phone_number: '+5511999999991', provider: 'default')
    c.save!(validate: false)
    c
  end
  let(:whatsapp_inbox) { Inbox.create!(account: account, channel: whatsapp_channel, name: 'WhatsApp Inbox') }
  let(:whatsapp_conversation) { create(:conversation, account: account, inbox: whatsapp_inbox) }

  let(:web_widget_channel) { Channel::WebWidget.create!(account: account, website_url: 'https://example.com') }
  let(:web_widget_inbox) { Inbox.create!(account: account, channel: web_widget_channel, name: 'Web Widget Inbox') }
  let(:web_widget_conversation) { create(:conversation, account: account, inbox: web_widget_inbox) }

  before do
    stub_request(:any, /waba\.360dialog\.io/).to_return(status: 200, body: '{}')
  end

  describe '.dispatch! on WhatsApp channel' do
    it 'creates input_select button message when options <= 3' do
      buttons = [
        { id: 'btn_1', title: 'Opção 1 com título longo' },
        { id: 'btn_2', title: 'Opção 2' }
      ]

      message = described_class.dispatch!(whatsapp_conversation, 'Como deseja prosseguir?', buttons)

      expect(message).to be_persisted
      expect(message.content_type).to eq('input_select')
      expect(message.content).to eq('Como deseja prosseguir?')
      items = message.content_attributes['items']
      expect(items.size).to eq(2)
      expect(items.first['title'].length).to be <= 20
      expect(items.first['value']).to eq('btn_1')
    end

    it 'creates input_select list message when options are between 4 and 10' do
      list_items = (1..6).map do |i|
        { id: "item_#{i}", title: "Serviço #{i}", description: "Descrição do serviço #{i}" }
      end

      message = described_class.dispatch!(whatsapp_conversation, 'Selecione o serviço:', list_items)

      expect(message).to be_persisted
      expect(message.content_type).to eq('input_select')
      items = message.content_attributes['items']
      expect(items.size).to eq(6)
      expect(items.first['title']).to eq('Serviço 1')
      expect(items.first['description']).to eq('Descrição do serviço 1')
    end
  end

  describe '.dispatch! on non-WhatsApp channel' do
    it 'formats as numbered plain text fallback for WebWidget channel' do
      options = [
        { id: '1', title: 'Falar com Comercial' },
        { id: '2', title: 'Suporte Técnico' }
      ]

      message = described_class.dispatch!(web_widget_conversation, 'Menu Principal:', options)

      expect(message).to be_persisted
      expect(message.content_type).to eq('text')
      expect(message.content).to eq("Menu Principal:\n\n1. Falar com Comercial\n2. Suporte Técnico")
    end
  end

  describe '.render_text_fallback' do
    it 'generates numbered text menu' do
      options = [{ title: 'Primeiro' }, { title: 'Segundo' }]
      rendered = described_class.render_text_fallback('Escolha:', options)

      expect(rendered).to eq("Escolha:\n\n1. Primeiro\n2. Segundo")
    end
  end
end
