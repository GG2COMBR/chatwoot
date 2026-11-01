# frozen_string_literal: true

class CreateCustomCampaignSpreadsheetTables < ActiveRecord::Migration[7.1]
  def change
    create_recipients_table
    create_logs_table
  end

  private

  def create_recipients_table
    create_table :custom_campaign_recipients do |t|
      t.bigint :campaign_id, null: false
      t.bigint :contact_id
      t.integer :row_number, null: false
      t.string :phone_number
      t.jsonb :row_data, default: {}
      t.string :status, default: 'pending', null: false
      t.text :error_message
      t.string :message_id
      t.integer :attempts, default: 0, null: false
      t.datetime :sent_at

      t.timestamps
    end

    add_index :custom_campaign_recipients, [:campaign_id, :row_number]
    add_index :custom_campaign_recipients, [:campaign_id, :status]
    add_index :custom_campaign_recipients, [:campaign_id, :phone_number]
    add_index :custom_campaign_recipients, :message_id
  end

  def create_logs_table
    create_table :custom_campaign_logs do |t|
      t.bigint :campaign_id, null: false
      t.bigint :contact_id
      t.string :contact_phone
      t.string :status, null: false
      t.text :message
      t.string :message_id
      t.datetime :sent_at

      t.timestamps
    end

    add_index :custom_campaign_logs, :campaign_id
    add_index :custom_campaign_logs, :contact_id
    add_index :custom_campaign_logs, :message_id
  end
end
