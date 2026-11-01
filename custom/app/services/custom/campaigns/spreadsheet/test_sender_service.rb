# frozen_string_literal: true

class Custom::Campaigns::Spreadsheet::TestSenderService
  pattr_initialize [:inbox!, :phone_number!, :template_params!]

  delegate :channel, to: :inbox

  def perform
    normalized_phone = Custom::PhoneNumbers::BrPhoneNormalizer.normalize_e164(phone_number)
    return { success: false, error: 'Invalid phone number' } if normalized_phone.blank?

    template_info = resolve_template
    return { success: false, error: 'Template name could not be resolved' } if template_info[:name].blank?

    dispatch_test(normalized_phone, template_info)
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def resolve_template
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params
    )
    name, namespace, lang_code, parameters = processor.call
    { name: name, namespace: namespace, lang_code: lang_code, parameters: parameters }
  end

  def dispatch_test(phone, info)
    payload = {
      name: info[:name],
      namespace: info[:namespace],
      lang_code: info[:lang_code],
      parameters: info[:parameters]
    }
    wamid = channel.send_template(phone, payload, nil)

    if wamid.present?
      { success: true, wamid: wamid }
    else
      { success: false, error: 'Empty message id returned from WhatsApp provider' }
    end
  end
end
