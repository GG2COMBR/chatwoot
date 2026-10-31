# frozen_string_literal: true

class Custom::Flows::ExecutionEngine
  class FlowExecutionError < StandardError; end

  attr_reader :session, :input_data

  def self.process!(session, input_data = {})
    new(session, input_data).process!
  end

  def initialize(session, input_data = {})
    @session = session
    @input_data = (input_data || {}).with_indifferent_access
  end

  def process!
    return session unless session.active?
    return session if nodes.empty?

    if session.current_node_id.blank?
      start_flow!
    else
      advance_flow!
    end

    session.save!
    session
  end

  private

  def nodes
    @nodes ||= (session.flow_snapshot&.dig('nodes') || []).map(&:with_indifferent_access)
  end

  def edges
    @edges ||= (session.flow_snapshot&.dig('edges') || []).map(&:with_indifferent_access)
  end

  def start_flow!
    initial_node = find_initial_node
    raise FlowExecutionError, 'No initial node found in flow snapshot' unless initial_node

    session.current_node_id = initial_node[:id]
    execute_node(initial_node)
  end

  def advance_flow!
    current_node = find_node(session.current_node_id)
    raise FlowExecutionError, "Current node #{session.current_node_id} not found" unless current_node

    next_node = find_next_node(current_node[:id])

    if next_node
      session.current_node_id = next_node[:id]
      execute_node(next_node)
    else
      handle_unmatched_transition(current_node)
    end
  end

  def find_initial_node
    explicit_start = nodes.find { |n| n[:type] == 'start' || n[:id] == 'start' }
    return explicit_start if explicit_start

    target_ids = edges.pluck(:target).to_set
    root_node = nodes.find { |n| target_ids.exclude?(n[:id]) }
    root_node || nodes.first
  end

  def find_node(node_id)
    nodes.find { |n| n[:id] == node_id }
  end

  def find_next_node(from_node_id)
    outgoing_edges = edges.select { |e| e[:source] == from_node_id }
    return nil if outgoing_edges.empty?

    matched_edge = outgoing_edges.find { |e| edge_condition_matches?(e[:condition]) } ||
                   outgoing_edges.find { |e| default_edge?(e) }

    matched_edge ? find_node(matched_edge[:target]) : nil
  end

  def default_edge?(edge)
    edge[:condition].blank? || edge.dig(:condition, :default) == true
  end

  def edge_condition_matches?(condition)
    return false if condition.blank?

    button_matches?(condition[:button_id]) ||
      value_matches?(condition[:value]) ||
      keyword_matches?(condition[:keyword])
  end

  def button_matches?(expected)
    expected.present? && expected == input_data[:button_id]
  end

  def value_matches?(expected)
    expected.present? && expected.to_s.casecmp(input_data[:content].to_s.strip).zero?
  end

  def keyword_matches?(expected)
    expected.present? && input_data[:content].to_s.downcase.include?(expected.to_s.downcase)
  end

  def execute_node(node)
    handler = handler_for(node[:type])
    handler.call(session, node, input_data)
  end

  def handle_unmatched_transition(current_node)
    retries = (session.context&.dig('retries') || 0) + 1
    session.update_context(retries: retries, last_unmatched_input: input_data[:content])

    # If an ai_fallback node is connected or available, route to it on multiple retries
    ai_node = nodes.find { |n| n[:type] == 'ai_fallback' }
    if ai_node && retries >= 2
      session.current_node_id = ai_node[:id]
      execute_node(ai_node)
    else
      # Re-execute current node to prompt user again
      execute_node(current_node)
    end
  end

  def handler_for(node_type)
    registry = {
      'message' => ->(s, n, _inp) { dispatch_simple_message(s, n) },
      'interactive_buttons' => ->(s, n, _inp) { dispatch_interactive(s, n) },
      'interactive_list' => ->(s, n, _inp) { dispatch_interactive(s, n) },
      'team_assignment' => ->(s, _n, _inp) { s.update!(status: :handoff) },
      'ai_fallback' => ->(s, _n, _inp) { s.update_context(ai_routed: true) },
      'finish' => ->(s, _n, _inp) { s.update!(status: :completed) }
    }

    registry[node_type.to_s] || ->(_s, _n, _inp) { true }
  end

  def dispatch_simple_message(session, node)
    msg_text = node.dig(:data, :text)
    session.update_context(last_message_sent: msg_text)
    return unless session.conversation && msg_text.present?

    session.conversation.messages.create!(
      account_id: session.account_id,
      inbox_id: session.conversation.inbox_id,
      message_type: :outgoing,
      content: msg_text
    )
  end

  def dispatch_interactive(session, node)
    text = node.dig(:data, :text)
    options = node.dig(:data, :buttons) || node.dig(:data, :items) || []
    session.update_context(last_prompt: text)
    return unless session.conversation && text.present?

    Custom::Flows::InteractiveMessageService.dispatch!(session.conversation, text, options)
  end
end
