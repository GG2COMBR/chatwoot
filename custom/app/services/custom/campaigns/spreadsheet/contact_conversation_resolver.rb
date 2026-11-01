# frozen_string_literal: true

class Custom::Campaigns::Spreadsheet::ContactConversationResolver
  pattr_initialize [:campaign!, :phone_number!, :name, :template_name!, :wamid!, :template_params, :content]

  delegate :inbox, to: :campaign

  def perform
    normalized_phone = Custom::PhoneNumbers::BrPhoneNormalizer.normalize_e164(phone_number)
    contact = find_or_create_contact(normalized_phone)
    contact_inbox = find_or_create_contact_inbox(contact, normalized_phone)

    conversation = find_or_create_conversation(contact, contact_inbox)
    message = create_campaign_message(conversation)

    { contact: contact, contact_inbox: contact_inbox, conversation: conversation, message: message }
  end

  private

  def find_or_create_contact(normalized_phone)
    contact = find_existing_contact(normalized_phone)
    return contact if contact

    inbox.account.contacts.create!(
      name: name.presence || normalized_phone,
      phone_number: normalized_phone
    )
  end

  def find_existing_contact(normalized_phone)
    variants = Custom::PhoneNumbers::BrPhoneNormalizer.e164_variants(normalized_phone)
    inbox.account.contacts.where(phone_number: variants).first
  end

  def find_or_create_contact_inbox(contact, normalized_phone)
    source_id = normalized_phone.delete_prefix('+')
    variants = Custom::PhoneNumbers::BrPhoneNormalizer.source_id_variants(source_id)

    contact_inbox = contact.contact_inboxes.where(inbox_id: inbox.id, source_id: variants).first
    return contact_inbox if contact_inbox

    contact_inbox = inbox.contact_inboxes.where(source_id: variants).first
    if contact_inbox
      contact_inbox.update!(contact_id: contact.id) if contact_inbox.contact_id != contact.id
      return contact_inbox
    end

    contact.contact_inboxes.create!(
      inbox_id: inbox.id,
      source_id: source_id
    )
  end

  def find_or_create_conversation(contact, contact_inbox)
    existing_conversation = contact_inbox.conversations.order(:created_at).last
    return existing_conversation if existing_conversation

    # For new contacts messaged via campaigns, create the conversation directly as resolved
    # so it does not flood the open queues of human agents.
    Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact.id,
      contact_inbox_id: contact_inbox.id,
      campaign_id: campaign.id,
      status: :resolved
    )
  end

  def create_campaign_message(conversation)
    was_resolved = conversation.resolved?

    safe_template_params = (template_params.presence || {}).deep_stringify_keys
    safe_template_params['name'] ||= template_name

    message = conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :template,
      status: :sent,
      source_id: wamid,
      content: resolved_content,
      sender: campaign.sender,
      additional_attributes: {
        campaign_id: campaign.id,
        template_name: template_name,
        template_params: safe_template_params
      }
    )

    # Keep conversation resolved if it was resolved before the campaign message
    conversation.update!(status: :resolved) if was_resolved

    message
  end

  def resolved_content
    return content if content.present?

    body = template_params&.dig('processed_params', 'body')
    base = campaign.message.presence || template_name
    return base if body.blank?

    interpolate_body_placeholders(base, body)
  end

  def interpolate_body_placeholders(base, body)
    b = body.stringify_keys
    base.to_s.gsub(/\{\{([^}]+)\}\}/) do
      k = Regexp.last_match(1).strip
      b.key?(k) ? b[k].to_s : "{{#{k}}}"
    end
  end
end
