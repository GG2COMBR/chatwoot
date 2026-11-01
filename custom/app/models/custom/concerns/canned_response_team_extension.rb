# frozen_string_literal: true

module Custom::Concerns::CannedResponseTeamExtension
  extend ActiveSupport::Concern

  included do
    has_many :canned_response_teams,
             class_name: 'Custom::CannedResponseTeam',
             foreign_key: :canned_response_id,
             dependent: :destroy,
             inverse_of: :canned_response

    has_many :teams,
             through: :canned_response_teams
  end

  def sync_teams!(assigned_team_ids)
    return if assigned_team_ids.nil?

    sanitized_ids = Array(assigned_team_ids).map(&:to_i).uniq
    valid_team_ids = account.teams.where(id: sanitized_ids).pluck(:id)

    canned_response_teams.where.not(team_id: valid_team_ids).destroy_all

    existing_ids = canned_response_teams.pluck(:team_id)
    new_team_ids = valid_team_ids - existing_ids

    new_team_ids.each do |tid|
      canned_response_teams.create!(account_id: account_id, team_id: tid)
    end
  end

  def as_json(options = {})
    json = super(options)
    json['team_ids'] = team_ids if json.is_a?(Hash)
    json
  end
end
