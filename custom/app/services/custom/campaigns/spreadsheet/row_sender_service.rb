# frozen_string_literal: true

class Custom::Campaigns::Spreadsheet::RowSenderService
  Result = Struct.new(:success?, :wamid, :error, keyword_init: true)

  pattr_initialize [:campaign!, :recipient!]

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def perform
    err = validate_preconditions
    return failure_result(err) if err

    interpolated_params = build_interpolated_params
    template_info = resolve_template(interpolated_params)
    return failure_result('Template could not be resolved') if template_info[:name].blank?

    dispatch_and_handle(template_info, interpolated_params)
  rescue StandardError => e
    Rails.logger.error "Campaign #{campaign.id} failed to send to #{recipient.phone_number}: #{e.message}"
    handle_failure(recipient.phone_number, e.message)
    failure_result(e.message)
  end

  private

  def validate_preconditions
    return 'Missing template parameters' if campaign.template_params.blank?
    return 'Missing recipient phone number' if recipient.phone_number.blank?

    nil
  end

  def resolve_template(interpolated_params)
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: interpolated_params
    )
    name, namespace, lang_code, parameters = processor.call
    { name: name, namespace: namespace, lang_code: lang_code, parameters: parameters }
  end

  def dispatch_and_handle(template_info, interpolated_params)
    phone = recipient.phone_number
    wamid = send_template(phone, template_info)

    if wamid.present?
      handle_success(phone, template_info[:name], wamid, interpolated_params)
      Result.new(success?: true, wamid: wamid, error: nil)
    else
      handle_failure(phone, 'Provider returned empty message id')
      failure_result('Provider returned empty message id')
    end
  end

  def send_template(to, info)
    payload = {
      name: info[:name],
      namespace: info[:namespace],
      lang_code: info[:lang_code],
      parameters: info[:parameters]
    }
    channel.send_template(to, payload, nil)
  end

  def handle_success(phone, template_name, wamid, template_params)
    recipient.update!(
      status: :sent,
      message_id: wamid,
      sent_at: Time.current,
      error_message: nil
    )

    resolver_result = resolve_contact_and_conversation(phone, template_name, wamid, template_params)
    record_success_telemetry(resolver_result, phone, template_name, wamid)
  end

  def resolve_contact_and_conversation(phone, template_name, wamid, template_params)
    Custom::Campaigns::Spreadsheet::ContactConversationResolver.new(
      campaign: campaign,
      phone_number: phone,
      name: recipient.row_data['name'].presence || recipient.row_data['nome'],
      template_name: template_name,
      wamid: wamid,
      template_params: template_params
    ).perform
  end

  def record_success_telemetry(result, phone, template_name, wamid)
    contact = result[:contact]
    recipient.update!(contact_id: contact.id) if recipient.contact_id.blank?

    sync_native_enterprise_recipient(contact, result[:contact_inbox], wamid)

    Custom::CampaignLog.create!(
      campaign_id: campaign.id,
      contact_id: contact.id,
      contact_phone: phone,
      status: 'sent',
      message: "Template #{template_name} sent successfully",
      message_id: wamid,
      sent_at: Time.current
    )
  end

  def sync_native_enterprise_recipient(contact, contact_inbox, wamid)
    return unless defined?(CampaignRecipient) && CampaignRecipient.table_exists?

    native_recipient = CampaignRecipient.find_or_initialize_by(campaign_id: campaign.id, contact_id: contact.id)
    native_recipient.account_id = campaign.account_id
    native_recipient.inbox_id = campaign.inbox_id
    native_recipient.contact_inbox_id = contact_inbox.id if contact_inbox
    native_recipient.source_id = wamid
    native_recipient.status = :sent
    native_recipient.sent_at = Time.current
    native_recipient.save!
  rescue StandardError => e
    Rails.logger.warn "Failed to sync native enterprise CampaignRecipient: #{e.message}"
  end

  def handle_failure(phone, error_message)
    recipient.update!(
      status: :failed,
      error_message: error_message
    )

    Custom::CampaignLog.create!(
      campaign_id: campaign.id,
      contact_id: recipient.contact_id,
      contact_phone: phone,
      status: 'failed',
      message: error_message,
      sent_at: Time.current
    )
  end

  def build_interpolated_params
    params = campaign.template_params.deep_dup
    processed = params['processed_params']&.deep_dup || {}
    processed['body'] = interpolate_body(processed['body'], params['spreadsheet_column_mapping'])
    params['processed_params'] = processed
    params
  end

  def interpolate_body(body, mapping)
    return {} if body.blank? || mapping.blank?

    res = body.dup
    res.each_key do |var_key|
      col = mapping[var_key.to_s]
      next if col.blank?

      val = recipient.row_data[col.to_s.strip.downcase]
      res[var_key] = val.to_s if val.present?
    end
    res
  end

  def failure_result(msg)
    Result.new(success?: false, wamid: nil, error: msg)
  end
end
