# frozen_string_literal: true

class Custom::CampaignLog < ApplicationRecord
  self.table_name = 'custom_campaign_logs'

  belongs_to :campaign
  belongs_to :contact, optional: true

  validates :campaign_id, presence: true
  validates :status, presence: true
end
