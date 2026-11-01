# frozen_string_literal: true

class CreateCustomCannedResponseTeams < ActiveRecord::Migration[7.0]
  def change
    create_table :custom_canned_response_teams do |t|
      t.integer :account_id, null: false
      t.integer :canned_response_id, null: false
      t.integer :team_id, null: false

      t.timestamps
    end

    add_index :custom_canned_response_teams,
              [:canned_response_id, :team_id],
              unique: true,
              name: 'idx_custom_canned_resp_teams_on_resp_and_team'

    add_index :custom_canned_response_teams,
              [:account_id, :team_id],
              name: 'idx_custom_canned_resp_teams_on_account_and_team'

    add_index :custom_canned_response_teams,
              [:account_id, :canned_response_id],
              name: 'idx_custom_canned_resp_teams_on_account_and_resp'
  end
end
