# frozen_string_literal: true

module Custom::Concerns::WhatsappOneoffCampaignServiceExtension
  def perform
    if campaign.spreadsheet_campaign?
      validate_campaign!
      Custom::Campaigns::Spreadsheet::BatchDispatcherService.new(campaign: campaign).perform
    else
      super
    end
  end
end
