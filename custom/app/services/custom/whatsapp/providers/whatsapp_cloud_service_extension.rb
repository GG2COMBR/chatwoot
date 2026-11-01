# frozen_string_literal: true

module Custom::Whatsapp::Providers::WhatsappCloudServiceExtension
  def send_text_message(phone_number, message)
    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        context: whatsapp_reply_context(message),
        **recipient_params(phone_number),
        text: { body: session_outgoing_content(message) },
        type: 'text'
      }.to_json
    )

    process_response(response, message)
  end

  def build_attachment_content(type, attachment, message)
    type_content = super
    type_content['caption'] = session_outgoing_content(message) if message.content.present? && %w[audio sticker].exclude?(type)
    type_content
  end
end
