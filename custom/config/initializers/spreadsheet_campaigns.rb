# frozen_string_literal: true

Rails.application.config.to_prepare do
  Campaign.include Custom::Concerns::CampaignExtension unless Campaign.included_modules.include?(Custom::Concerns::CampaignExtension)

  unless Whatsapp::OneoffCampaignService <= Custom::Concerns::WhatsappOneoffCampaignServiceExtension
    Whatsapp::OneoffCampaignService.prepend(Custom::Concerns::WhatsappOneoffCampaignServiceExtension)
  end

  unless Api::V1::Accounts::CampaignsController <= Custom::Concerns::CampaignsControllerExtension
    Api::V1::Accounts::CampaignsController.prepend(Custom::Concerns::CampaignsControllerExtension)
  end
end
