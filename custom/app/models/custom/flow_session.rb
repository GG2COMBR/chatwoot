# frozen_string_literal: true

class Custom::FlowSession < ApplicationRecord
  self.table_name = 'custom_flow_sessions'

  belongs_to :account
  belongs_to :custom_flow,
             class_name: 'Custom::Flow',
             inverse_of: :custom_flow_sessions
  belongs_to :conversation

  enum :status, {
    active: 0,
    completed: 1,
    handoff: 2,
    interrupted_by_human: 3,
    timed_out: 4,
    failed: 5
  }

  validates :account_id, presence: true
  validates :custom_flow_id, presence: true
  validates :conversation_id, presence: true
  validates :status, presence: true

  scope :active, -> { where(status: :active) }
  scope :completed, -> { where(status: :completed) }

  before_create :set_initial_snapshot

  def update_context(new_data)
    self.context = (context || {}).merge(new_data.stringify_keys)
    save!
  end

  def current_node
    return nil if current_node_id.blank?

    nodes = flow_snapshot&.dig('nodes') || []
    nodes.find { |n| n['id'] == current_node_id || n[:id] == current_node_id }&.with_indifferent_access
  end

  private

  def set_initial_snapshot
    return if flow_snapshot.present? && !flow_snapshot.empty?
    return unless custom_flow

    self.flow_snapshot = {
      flow_id: custom_flow.id,
      name: custom_flow.name,
      nodes: custom_flow.nodes,
      edges: custom_flow.edges,
      snapshot_taken_at: Time.current.iso8601
    }
  end
end
