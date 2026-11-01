# frozen_string_literal: true

class Custom::CampaignRecipient < ApplicationRecord
  self.table_name = 'custom_campaign_recipients'

  belongs_to :campaign
  belongs_to :contact, optional: true

  enum :status, {
    pending: 'pending',
    queued: 'queued',
    sent: 'sent',
    failed: 'failed',
    skipped: 'skipped'
  }

  validates :campaign_id, presence: true
  validates :row_number, presence: true

  def terminal?
    sent? || failed? || skipped?
  end
end
