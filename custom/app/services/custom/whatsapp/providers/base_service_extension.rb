# frozen_string_literal: true

module Custom::Whatsapp::Providers::BaseServiceExtension
  def session_outgoing_content(message)
    Custom::Whatsapp::SessionContentFormatter.new(message: message).perform
  end
end
