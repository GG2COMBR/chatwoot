# frozen_string_literal: true

class Custom::Ai::BedrockService
  DEFAULT_MODEL = 'amazon.nova-lite-v1:0'
  DEFAULT_MAX_TOKENS = 300
  DEFAULT_TEMPERATURE = 0.3
  DEFAULT_FALLBACK_TEXT = 'Compreendo sua dúvida! Para melhor lhe atender com precisão, vou transferir sua conversa para um atendente humano.'
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.strip
    Você é a assistente virtual inteligente da GG2 no WhatsApp.
    Seja sempre gentil, concisa, objetiva e útil.
    Responda em português (Brasil) de forma clara, utilizando formatação simples para WhatsApp (negrito com * e quebras de linha).
    Nunca invente informações de pedidos ou dados bancários inexistentes.
    Se o cliente desejar falar com um ser humano ou se você não tiver certeza da resposta, informe amigavelmente que irá transferi-lo.
  PROMPT

  def self.chat(prompt, options = {})
    new(options).chat(prompt)
  end

  def initialize(options = {})
    @options = (options || {}).with_indifferent_access
    configure_credentials!
  end

  def chat(prompt)
    return fallback_response('Prompt vazio') if prompt.blank?

    chat_session = RubyLLM.chat(model: model)
    chat_session.with_temperature(temperature)
    chat_session.with_max_output_tokens(max_tokens)
    chat_session.with_instructions(system_prompt) if system_prompt.present?

    append_history(chat_session)

    response = chat_session.ask(prompt.to_s)
    content = extract_content(response)

    {
      status: 'success',
      model: model,
      content: content,
      prompt: prompt
    }
  rescue StandardError => e
    Rails.logger.error("[BedrockService] Error: #{e.message}")
    fallback_response(e.message)
  end

  private

  def model
    @options[:model].presence || DEFAULT_MODEL
  end

  def temperature
    (@options[:temperature] || DEFAULT_TEMPERATURE).to_f
  end

  def max_tokens
    (@options[:max_tokens] || DEFAULT_MAX_TOKENS).to_i
  end

  def system_prompt
    @options[:system_prompt].presence || DEFAULT_SYSTEM_PROMPT
  end

  def append_history(chat_session)
    history = @options[:history] || []
    history.each do |item|
      role = (item[:role] || item['role'] || :user).to_sym
      content = item[:content] || item['content']
      chat_session.add_message(role: role, content: content) if content.present?
    end
  end

  def extract_content(response)
    if response.respond_to?(:content)
      response.content.to_s.strip
    elsif response.is_a?(Hash)
      response[:content] || response['content']
    else
      response.to_s.strip
    end
  end

  def fallback_response(reason)
    {
      status: 'fallback',
      model: model,
      content: DEFAULT_FALLBACK_TEXT,
      reason: reason
    }
  end

  def configure_credentials!
    region = @options[:region] || ENV['CAPTAIN_BEDROCK_REGION'] || 'us-east-1'
    access_key = @options[:access_key] || ENV['CAPTAIN_BEDROCK_ACCESS_KEY_ID'] || 'test-key'
    secret_key = @options[:secret_key] || ENV['CAPTAIN_BEDROCK_SECRET_ACCESS_KEY'] || 'test-secret'

    RubyLLM.configure do |c|
      c.bedrock_region = region
      c.bedrock_api_key = access_key
      c.bedrock_secret_key = secret_key
    end
  end
end
