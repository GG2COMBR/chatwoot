# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Whatsapp::SessionContentFormatter do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_whatsapp, account: account, validate_provider_config: false, sync_templates: false) }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, name: 'Bruna Silva Santos', display_name: 'Bruna') }
  let(:agent_bot) { create(:agent_bot) }

  describe '#perform' do
    context 'when agent identifier is disabled on the inbox' do
      let(:message) do
        create(:message, account: account, inbox: inbox, conversation: conversation, sender: agent, content: 'Olá, tudo bem?')
      end

      it 'returns the raw outgoing_content without prefix' do
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('Olá, tudo bem?')
      end
    end

    context 'when agent identifier is enabled on the inbox channel' do
      before do
        channel.provider_config['agent_identifier'] = {
          'enabled' => true,
          'format' => 'bold',
          'bot_name' => 'Bia'
        }
        channel.save!
      end

      it 'prefixes human agent first name in bold format by default' do
        message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: agent, content: 'Olá, tudo bem?')
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('*Bruna*: Olá, tudo bem?')
      end

      it 'supports bracket format [Nome]: message' do
        channel.provider_config['agent_identifier']['format'] = 'bracket'
        channel.save!

        message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: agent, content: 'Como posso ajudar?')
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('[Bruna]: Como posso ajudar?')
      end

      it 'supports plain format Nome: message' do
        channel.provider_config['agent_identifier']['format'] = 'plain'
        channel.save!

        message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: agent, content: 'Bom dia!')
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('Bruna: Bom dia!')
      end

      it 'prefixes bot messages with the custom bot_name' do
        message = create(
          :message,
          account: account,
          inbox: inbox,
          conversation: conversation,
          sender: agent_bot,
          content: 'Bem-vindo ao atendimento!'
        )
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('*Bia*: Bem-vindo ao atendimento!')
      end

      it 'does not prefix private notes' do
        message = create(
          :message,
          account: account,
          inbox: inbox,
          conversation: conversation,
          sender: agent,
          content: 'Nota interna da equipe',
          private: true
        )
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('Nota interna da equipe')
      end

      it 'does not prefix template messages' do
        message = create(
          :message,
          account: account,
          inbox: inbox,
          conversation: conversation,
          sender: agent,
          content: 'Template text',
          additional_attributes: { 'template_params' => { 'name' => 'hello_world' } }
        )
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('Template text')
      end

      it 'does not prefix campaign messages' do
        message = create(
          :message,
          account: account,
          inbox: inbox,
          conversation: conversation,
          sender: agent,
          content: 'Promocao especial',
          additional_attributes: { 'campaign_id' => 123 }
        )
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq('Promocao especial')
      end

      it 'does not prefix CSAT survey messages' do
        message = create(
          :message,
          account: account,
          inbox: inbox,
          conversation: conversation,
          sender: agent,
          content: 'Por favor, avalie nosso atendimento',
          content_type: :input_csat
        )
        formatter = described_class.new(message: message)
        expect(formatter.perform).to eq(message.outgoing_content)
        expect(formatter.perform).not_to include('*Bruna*:')
      end
    end
  end
end
