# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Ai::BedrockService do
  let(:chat_mock) { instance_double(RubyLLM::Chat) }

  before do
    allow(RubyLLM).to receive(:chat).and_return(chat_mock)
    allow(chat_mock).to receive(:with_temperature).and_return(chat_mock)
    allow(chat_mock).to receive(:with_max_output_tokens).and_return(chat_mock)
    allow(chat_mock).to receive(:with_instructions).and_return(chat_mock)
    allow(chat_mock).to receive(:add_message).and_return(chat_mock)
  end

  describe '.chat' do
    it 'configures RubyLLM options properly with default parameters' do
      expect(RubyLLM).to receive(:chat).with(model: 'amazon.nova-lite-v1:0').and_return(chat_mock)
      expect(chat_mock).to receive(:with_temperature).with(0.3)
      expect(chat_mock).to receive(:with_max_output_tokens).with(300)
      expect(chat_mock).to receive(:with_instructions).with(kind_of(String))
      expect(chat_mock).to receive(:ask).with('Qual o prazo de entrega?').and_return(
        instance_double(RubyLLM::Message, content: 'Nosso prazo padrão é de 2 a 5 dias úteis.')
      )

      described_class.chat('Qual o prazo de entrega?')
    end

    it 'returns generated response content and model metadata' do
      response_double = instance_double(RubyLLM::Message, content: 'Nosso prazo padrão é de 2 a 5 dias úteis.')
      allow(chat_mock).to receive(:ask).and_return(response_double)

      result = described_class.chat('Qual o prazo de entrega?')

      expect(result[:status]).to eq('success')
      expect(result[:content]).to eq('Nosso prazo padrão é de 2 a 5 dias úteis.')
      expect(result[:model]).to eq('amazon.nova-lite-v1:0')
    end

    it 'passes custom model, system_prompt, and temperature' do
      expect(RubyLLM).to receive(:chat).with(model: 'anthropic.claude-3-5-haiku').and_return(chat_mock)
      expect(chat_mock).to receive(:with_temperature).with(0.7)
      expect(chat_mock).to receive(:with_max_output_tokens).with(150)
      expect(chat_mock).to receive(:with_instructions).with('Prompt customizado')
      expect(chat_mock).to receive(:ask).with('Olá').and_return('Resposta simples')

      result = described_class.chat(
        'Olá',
        model: 'anthropic.claude-3-5-haiku',
        temperature: 0.7,
        max_tokens: 150,
        system_prompt: 'Prompt customizado'
      )

      expect(result[:status]).to eq('success')
      expect(result[:content]).to eq('Resposta simples')
    end

    it 'replays history messages into the chat session' do
      expect(chat_mock).to receive(:add_message).with(role: :user, content: 'Pergunta 1')
      expect(chat_mock).to receive(:add_message).with(role: :assistant, content: 'Resposta 1')
      expect(chat_mock).to receive(:ask).with('Pergunta 2').and_return('Resposta 2')

      history = [
        { role: 'user', content: 'Pergunta 1' },
        { role: 'assistant', content: 'Resposta 1' }
      ]

      result = described_class.chat('Pergunta 2', history: history)
      expect(result[:status]).to eq('success')
      expect(result[:content]).to eq('Resposta 2')
    end

    it 'returns fallback response when prompt is blank' do
      result = described_class.chat('')

      expect(result[:status]).to eq('fallback')
      expect(result[:content]).to include('transferir')
    end

    it 'rescues errors and returns safe fallback response' do
      expect(chat_mock).to receive(:ask).and_raise(StandardError.new('Bedrock throttled'))

      result = described_class.chat('Pergunta')

      expect(result[:status]).to eq('fallback')
      expect(result[:reason]).to eq('Bedrock throttled')
      expect(result[:content]).to include('transferir')
    end

    it 'configures provider specific credentials for openai' do
      expect(chat_mock).to receive(:ask).and_return('OpenAI response')

      result = described_class.chat('Olá', provider: 'openai', model: 'gpt-4o-mini', api_key: 'sk-test')
      expect(result[:status]).to eq('success')
      expect(result[:model]).to eq('gpt-4o-mini')
    end

    it 'configures provider specific credentials for anthropic' do
      expect(chat_mock).to receive(:ask).and_return('Claude response')

      result = described_class.chat('Olá', provider: 'anthropic', model: 'claude-3-5-haiku-latest', api_key: 'sk-ant-test')
      expect(result[:status]).to eq('success')
      expect(result[:model]).to eq('claude-3-5-haiku-latest')
    end

    it 'configures provider specific credentials for ollama' do
      expect(chat_mock).to receive(:ask).and_return('Ollama response')

      result = described_class.chat('Olá', provider: 'ollama', model: 'llama3.2', api_base: 'http://localhost:11434')
      expect(result[:status]).to eq('success')
      expect(result[:model]).to eq('llama3.2')
    end
  end
end
