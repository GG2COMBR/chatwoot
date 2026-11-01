# frozen_string_literal: true

Rails.application.config.to_prepare do
  if defined?(Whatsapp::Providers::BaseService) &&
     !(Whatsapp::Providers::BaseService <= Custom::Whatsapp::Providers::BaseServiceExtension)
    Whatsapp::Providers::BaseService.prepend(Custom::Whatsapp::Providers::BaseServiceExtension)
  end

  if defined?(Whatsapp::Providers::WhatsappCloudService) &&
     !(Whatsapp::Providers::WhatsappCloudService <= Custom::Whatsapp::Providers::WhatsappCloudServiceExtension)
    Whatsapp::Providers::WhatsappCloudService.prepend(Custom::Whatsapp::Providers::WhatsappCloudServiceExtension)
  end

  if defined?(Whatsapp::Providers::Whatsapp360DialogService) &&
     !(Whatsapp::Providers::Whatsapp360DialogService <= Custom::Whatsapp::Providers::Whatsapp360DialogServiceExtension)
    Whatsapp::Providers::Whatsapp360DialogService.prepend(Custom::Whatsapp::Providers::Whatsapp360DialogServiceExtension)
  end
end
