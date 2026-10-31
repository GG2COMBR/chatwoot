# frozen_string_literal: true

class Custom::Flows::InteractiveMessageService
  MAX_BUTTONS = 3
  MAX_LIST_ITEMS = 10
  BUTTON_TITLE_MAX_LENGTH = 20
  LIST_TITLE_MAX_LENGTH = 24

  class << self
    def dispatch!(conversation, text, options)
      new(conversation, text, options).dispatch!
    end

    def render_text_fallback(text, options)
      new(nil, text, options).send(:formatted_text_menu)
    end
  end

  def initialize(conversation, text, options)
    @conversation = conversation
    @text = text
    @options = normalize_options(options)
  end

  def dispatch!
    if whatsapp_channel?
      dispatch_whatsapp_interactive
    else
      dispatch_text_fallback
    end
  end

  private

  attr_reader :conversation, :text, :options

  def whatsapp_channel?
    return false unless conversation&.inbox&.channel

    conversation.inbox.channel.is_a?(Channel::Whatsapp)
  end

  def dispatch_whatsapp_interactive
    items = if options.size <= MAX_BUTTONS
              format_button_items
            else
              format_list_items
            end

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: text,
      content_type: :input_select,
      content_attributes: { 'items' => items }
    )
  end

  def dispatch_text_fallback
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: formatted_text_menu,
      content_type: :text,
      content_attributes: { 'raw_options' => options }
    )
  end

  def format_button_items
    options.take(MAX_BUTTONS).map do |opt|
      {
        'title' => opt[:title].to_s.truncate(BUTTON_TITLE_MAX_LENGTH),
        'value' => opt[:id] || opt[:value] || opt[:title]
      }
    end
  end

  def format_list_items
    options.take(MAX_LIST_ITEMS).map do |opt|
      item = {
        'title' => opt[:title].to_s.truncate(LIST_TITLE_MAX_LENGTH),
        'value' => opt[:id] || opt[:value] || opt[:title]
      }
      item['description'] = opt[:description].to_s.truncate(72) if opt[:description].present?
      item
    end
  end

  def formatted_text_menu
    lines = [text, '']
    options.each_with_index do |opt, idx|
      lines << "#{idx + 1}. #{opt[:title]}"
    end
    lines.join("\n")
  end

  def normalize_options(raw_options)
    (raw_options || []).map do |opt|
      if opt.is_a?(String)
        { id: opt, title: opt, value: opt }
      else
        opt.with_indifferent_access
      end
    end
  end
end
