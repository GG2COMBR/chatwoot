# frozen_string_literal: true

class Custom::Flows::ExecutionEngine
  include Custom::Flows::NodeHandlers

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

    session.current_node_id.blank? ? start_flow! : advance_flow!
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
      session.update_context(retries: 0)
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
      status_matches?(condition[:status]) ||
      keyword_matches?(condition[:keyword])
  end

  def button_matches?(expected)
    expected.present? && expected == input_data[:button_id]
  end

  def value_matches?(expected)
    expected.present? && expected.to_s.casecmp(input_data[:content].to_s.strip).zero?
  end
  alias status_matches? value_matches?

  def keyword_matches?(expected)
    expected.present? && input_data[:content].to_s.downcase.include?(expected.to_s.downcase)
  end

  def execute_node(node)
    handler = node_handlers[node[:type].to_s]
    send(handler, session, node) if handler
    schedule_inactivity_monitor(node)
  end

  def schedule_inactivity_monitor(node)
    return unless session.active?
    return if %w[finish team_assignment].include?(node[:type].to_s)

    Custom::Flows::InactivityJob.schedule_for(session, node)
  end

  def node_handlers
    {
      'message' => :dispatch_simple_message,
      'interactive_buttons' => :dispatch_interactive,
      'interactive_list' => :dispatch_interactive,
      'team_assignment' => :dispatch_team_assignment,
      'business_hours' => :evaluate_business_hours_node,
      'async_action' => :dispatch_async_action,
      'ai_fallback' => :dispatch_ai_fallback,
      'ai_agent' => :dispatch_ai_fallback,
      'finish' => :finish_node
    }
  end

  def handle_unmatched_transition(current_node)
    retries = (session.context&.dig('retries') || 0) + 1
    max_retries = (current_node.dig(:data, :max_retries) || 2).to_i
    session.update_context(retries: retries, last_unmatched_input: input_data[:content])

    if retries >= max_retries
      route_escape_path!(current_node)
    else
      re_prompt_current_node!(current_node)
    end
  end

  def route_escape_path!(current_node)
    escape_node = find_escape_node(current_node)
    if escape_node
      session.current_node_id = escape_node[:id]
      execute_node(escape_node)
    else
      trigger_human_handoff(session, current_node, 'max_retries_exceeded')
    end
  end

  def find_escape_node(current_node)
    escape_edge = edges.select { |e| e[:source] == current_node[:id] }.find do |e|
      e.dig(:condition, :fallback) == true || e.dig(:condition, :on_error) == true
    end
    return find_node(escape_edge[:target]) if escape_edge

    nodes.find { |n| n[:type] == 'ai_fallback' || n[:type] == 'ai_agent' }
  end

  def re_prompt_current_node!(current_node)
    msg = current_node.dig(:data, :retry_message)
    create_outgoing_message(msg) if msg.present?
    execute_node(current_node)
  end
end
