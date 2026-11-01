# frozen_string_literal: true

class Custom::Campaigns::SendSpreadsheetRowJob < ApplicationJob
  queue_as :campaigns_processing

  def perform(recipient_id)
    recipient = Custom::CampaignRecipient.find_by(id: recipient_id)
    return unless recipient
    return if recipient.terminal?

    campaign = recipient.campaign
    return if campaign.completed?

    recipient.with_lock do
      recipient.reload
      return if recipient.terminal?

      recipient.update!(status: :queued, attempts: recipient.attempts + 1)
    end

    Custom::Campaigns::Spreadsheet::RowSenderService.new(
      campaign: campaign,
      recipient: recipient
    ).perform
  ensure
    check_and_mark_campaign_completed(recipient&.campaign)
  end

  private

  def check_and_mark_campaign_completed(campaign)
    return unless campaign
    return if campaign.completed?

    # If all recipients are in terminal status, complete the campaign
    pending_count = campaign.custom_campaign_recipients.where(status: [:pending, :queued]).count
    campaign.completed! if pending_count.zero?
  end
end
