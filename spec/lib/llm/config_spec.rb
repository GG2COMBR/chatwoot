require 'rails_helper'

RSpec.describe Llm::Config do
  describe '.configure_ruby_llm' do
    it 'adds the API version to the configured OpenAI endpoint' do
      original_base = RubyLLM.config.openai_api_base
      InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: 'https://example.test/')

      described_class.send(:configure_ruby_llm)

      expect(RubyLLM.config.openai_api_base).to eq('https://example.test/v1')
    ensure
      RubyLLM.configure { |config| config.openai_api_base = original_base }
    end

    context 'when the provider is bedrock' do
      let(:original_key) { RubyLLM.config.bedrock_api_key }
      let(:original_secret) { RubyLLM.config.bedrock_secret_key }
      let(:original_region) { RubyLLM.config.bedrock_region }

      before do
        InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_LLM_PROVIDER').update!(value: 'bedrock')
        InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_BEDROCK_ACCESS_KEY_ID').update!(value: 'test-access-key')
        InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_BEDROCK_SECRET_ACCESS_KEY').update!(value: 'test-secret-key')
        InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_BEDROCK_REGION').update!(value: 'us-east-1')
      end

      after do
        InstallationConfig.where(
          name: %w[CAPTAIN_LLM_PROVIDER CAPTAIN_BEDROCK_ACCESS_KEY_ID CAPTAIN_BEDROCK_SECRET_ACCESS_KEY CAPTAIN_BEDROCK_REGION]
        ).destroy_all
        RubyLLM.configure do |config|
          config.bedrock_api_key = original_key
          config.bedrock_secret_key = original_secret
          config.bedrock_region = original_region
        end
      end

      it 'configures RubyLLM with the Bedrock credentials' do
        described_class.send(:configure_ruby_llm)

        expect(RubyLLM.config.bedrock_api_key).to eq('test-access-key')
        expect(RubyLLM.config.bedrock_secret_key).to eq('test-secret-key')
        expect(RubyLLM.config.bedrock_region).to eq('us-east-1')
      end
    end
  end
end
