require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze
  OPENAI_PROVIDER = 'openai'.freeze
  BEDROCK_PROVIDER = 'bedrock'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def bedrock_provider?
      provider == BEDROCK_PROVIDER
    end

    def with_api_key(api_key, api_base: nil)
      initialize!

      # Bedrock authenticates with AWS credentials configured globally in
      # configure_ruby_llm, not with a per-request API key, so we reuse the
      # globally-configured context instead of overriding OpenAI settings.
      return yield RubyLLM.context if bedrock_provider?

      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger

        if provider == BEDROCK_PROVIDER
          configure_bedrock(config)
        else
          configure_openai(config)
        end
      end
    end

    def configure_openai(config)
      config.openai_api_key = system_api_key if system_api_key.present?
      config.openai_api_base = "#{openai_endpoint.chomp('/')}/v1" if openai_endpoint.present?
      config.openai_protocol = :chat_completions
    end

    def configure_bedrock(config)
      config.bedrock_api_key = installation_value('CAPTAIN_BEDROCK_ACCESS_KEY_ID')
      config.bedrock_secret_key = installation_value('CAPTAIN_BEDROCK_SECRET_ACCESS_KEY')
      config.bedrock_region = installation_value('CAPTAIN_BEDROCK_REGION')
      session_token = installation_value('CAPTAIN_BEDROCK_SESSION_TOKEN')
      config.bedrock_session_token = session_token if session_token.present?
    end

    def provider
      installation_value('CAPTAIN_LLM_PROVIDER').presence&.downcase || OPENAI_PROVIDER
    end

    def system_api_key
      installation_value('CAPTAIN_OPEN_AI_API_KEY')
    end

    def openai_endpoint
      installation_value('CAPTAIN_OPEN_AI_ENDPOINT')
    end

    def installation_value(name)
      InstallationConfig.find_by(name: name)&.value
    end
  end
end
