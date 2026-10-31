# frozen_string_literal: true

class CreateCustomFlowsAndCustomFlowSessions < ActiveRecord::Migration[7.2]
  def change
    create_custom_flows
    create_custom_flow_sessions
  end

  private

  def create_custom_flows
    create_table :custom_flows do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.string :trigger_type, default: 'default', null: false
      t.jsonb :trigger_config, default: {}, null: false
      t.jsonb :nodes, default: [], null: false
      t.jsonb :edges, default: [], null: false

      t.timestamps
    end

    add_index :custom_flows, :account_id
    add_index :custom_flows, [:account_id, :status]
  end

  def create_custom_flow_sessions
    create_table :custom_flow_sessions do |t|
      t.bigint :account_id, null: false
      t.bigint :custom_flow_id, null: false
      t.bigint :conversation_id, null: false
      t.integer :status, default: 0, null: false
      t.string :current_node_id
      t.jsonb :flow_snapshot, default: {}, null: false
      t.jsonb :context, default: {}, null: false
      t.datetime :last_activity_at

      t.timestamps
    end

    add_flow_sessions_indexes
  end

  def add_flow_sessions_indexes
    add_index :custom_flow_sessions, :account_id
    add_index :custom_flow_sessions, :custom_flow_id
    add_index :custom_flow_sessions, :conversation_id
    add_index :custom_flow_sessions, [:conversation_id, :status]
    add_index :custom_flow_sessions, [:account_id, :status]
    add_index :custom_flow_sessions, :last_activity_at
  end
end
