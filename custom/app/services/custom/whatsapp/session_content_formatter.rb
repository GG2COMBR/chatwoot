# frozen_string_literal: true

class Custom::Whatsapp::SessionContentFormatter
  DEFAULT_BOT_DISPLAY_NAME = 'Assistente Virtual'

  pattr_initialize [:message!]

  def perform
    content = message.outgoing_content
    return content if content.blank?
    return content unless prepend_sender_name?

    format_with_prefix(content)
  end

  private

  def prepend_sender_name?
    return false if message.private?
    return false if message.input_csat?
    return false if campaign_message?
    return false if template_message?
    return false unless inbox_identifier_enabled?
    return false if sender_name.blank?

    true
  end

  def inbox_identifier_enabled?
    config = identifier_config
    ActiveModel::Type::Boolean.new.cast(config['enabled'])
  end

  def identifier_config
    channel = message.inbox&.channel
    if channel.respond_to?(:provider_config) && channel.provider_config&.dig('agent_identifier').is_a?(Hash)
      return channel.provider_config['agent_identifier']
    end

    {}
  end

  def prefix_format
    identifier_config['format'].presence || 'bold'
  end

  def format_with_prefix(content)
    case prefix_format
    when 'bracket'
      "[#{sender_name}]: #{content}"
    when 'plain'
      "#{sender_name}: #{content}"
    else
      "*#{sender_name}*: #{content}"
    end
  end

  def campaign_message?
    message.additional_attributes&.dig('campaign_id').present?
  end

  def template_message?
    message.additional_attributes&.dig('template_params').present?
  end

  def sender_name
    @sender_name ||= if bot_message? || virtual_assistant_name?(resolved_sender_name)
                       custom_bot_display_name
                     else
                       first_name(resolved_sender_name)
                     end
  end

  def custom_bot_display_name
    identifier_config['bot_name'].presence || DEFAULT_BOT_DISPLAY_NAME
  end

  def resolved_sender_name
    message.sender&.try(:available_name).presence || message.sender&.try(:name)
  end

  def virtual_assistant_name?(full_name)
    full_name.to_s.squish.casecmp?(DEFAULT_BOT_DISPLAY_NAME)
  end

  def first_name(full_name)
    full_name.to_s.split(/\s+/).first.presence
  end

  def bot_message?
    message.sender_type == 'AgentBot' || message.sender.is_a?(AgentBot)
  end
end
