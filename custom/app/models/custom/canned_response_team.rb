# frozen_string_literal: true

class Custom::CannedResponseTeam < ApplicationRecord
  self.table_name = 'custom_canned_response_teams'

  belongs_to :account
  belongs_to :canned_response
  belongs_to :team

  validates :account_id, presence: true
  validates :canned_response_id, presence: true, uniqueness: { scope: :team_id }
  validates :team_id, presence: true
end
