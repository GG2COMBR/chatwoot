require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-6-luna'.freeze
  OPENAI_PROVIDER = 'openai'.freeze
  BEDROCK_PROVIDER = 'bedrock'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized
      return mark_initialized unless provider_configured?

      configure_ruby_llm
      mark_initialized
    rescue StandardError => e
      Rails.logger.error "Failed to configure RubyLLM: #{e.message}"
      mark_initialized
    end

    def reset!
      @initialized = false
    end

    def provider
      InstallationConfig.find_by(name: 'CAPTAIN_LLM_PROVIDER')&.value.presence || OPENAI_PROVIDER
    end

    def bedrock?
      provider == BEDROCK_PROVIDER
    end

    def openai?
      provider == OPENAI_PROVIDER
    end

    private

    def mark_initialized
      @initialized = true
    end

    def provider_configured?
      case provider
      when BEDROCK_PROVIDER
        bedrock_credentials_present?
      else
        openai_credentials_present?
      end
    end

    def openai_credentials_present?
      api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
      api_key.present?
    end

    def bedrock_credentials_present?
      access_key = InstallationConfig.find_by(name: 'CAPTAIN_BEDROCK_ACCESS_KEY_ID')&.value
      secret_key = InstallationConfig.find_by(name: 'CAPTAIN_BEDROCK_SECRET_ACCESS_KEY')&.value
      region = InstallationConfig.find_by(name: 'CAPTAIN_BEDROCK_REGION')&.value

      access_key.present? && secret_key.present? && region.present?
    end

    def configure_ruby_llm
      case provider
      when BEDROCK_PROVIDER
        configure_bedrock
      else
        configure_openai
      end
    end

    def configure_openai
      api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
      RubyLLM.configure do |c|
        c.openai_api_key = api_key
      end
    end

    def configure_bedrock
      access_key = InstallationConfig.find_by(name: 'CAPTAIN_BEDROCK_ACCESS_KEY_ID')&.value
      secret_key = InstallationConfig.find_by(name: 'CAPTAIN_BEDROCK_SECRET_ACCESS_KEY')&.value
      region = InstallationConfig.find_by(name: 'CAPTAIN_BEDROCK_REGION')&.value

      RubyLLM.configure do |c|
        c.bedrock_access_key_id = access_key
        c.bedrock_secret_access_key = secret_key
        c.bedrock_region = region
      end
    end
  end
end
