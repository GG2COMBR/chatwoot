# frozen_string_literal: true

module Custom::Whatsapp::Providers::Whatsapp360DialogServiceExtension
  def send_text_message(phone_number, message)
    response = HTTParty.post(
      "#{api_base_path}/messages",
      headers: api_headers,
      body: {
        to: phone_number,
        text: { body: session_outgoing_content(message) },
        type: 'text'
      }.to_json
    )

    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    type_content = {
      'link': attachment.download_url
    }
    type_content['caption'] = session_outgoing_content(message) if message.content.present? && %w[audio sticker].exclude?(type)
    type_content['filename'] = attachment.file.filename if type == 'document'

    response = HTTParty.post(
      "#{api_base_path}/messages",
      headers: api_headers,
      body: {
        :to => phone_number,
        :type => type,
        type.to_s => type_content
      }.to_json
    )

    process_response(response, message)
  end
end
