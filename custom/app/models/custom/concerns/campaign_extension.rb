# frozen_string_literal: true

module Custom::Concerns::CampaignExtension
  extend ActiveSupport::Concern

  included do
    has_one_attached :audience_file
    has_many :custom_campaign_recipients,
             class_name: 'Custom::CampaignRecipient',
             foreign_key: :campaign_id,
             dependent: :destroy,
             inverse_of: :campaign

    has_many :custom_campaign_logs,
             class_name: 'Custom::CampaignLog',
             foreign_key: :campaign_id,
             dependent: :destroy,
             inverse_of: :campaign
  end

  def spreadsheet_campaign?
    audience_file.attached? || template_params&.dig('spreadsheet_column_mapping').present?
  end

  def spreadsheet_stats
    recipients = custom_campaign_recipients
    counts = recipients.group(:status).count

    {
      total: recipients.count,
      pending: counts['pending'].to_i,
      queued: counts['queued'].to_i,
      sent: counts['sent'].to_i,
      failed: counts['failed'].to_i,
      skipped: counts['skipped'].to_i
    }
  end
end
