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

  def finish_node(session, _node)
    session.update!(status: :completed)
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

  def dispatch_team_assignment(session, node)
    team_name = node.dig(:data, :team_name)
    team = session.account.teams.where('lower(name) = ?', team_name.to_s.downcase).first if team_name.present?

    config = node[:data] || {}
    result = Custom::Flows::ScheduleEvaluatorService.route_and_handoff!(session.conversation, team, config)
    session.update!(status: :handoff)
    session.update_context(handoff_result: result)
  end

  def evaluate_business_hours_node(session, node)
    is_open = Custom::Flows::ScheduleEvaluatorService.open_now?(
      node[:data] || session.conversation.inbox,
      timezone: node.dig(:data, :timezone) || 'America/Sao_Paulo'
    )
    session.update_context(business_hours_open: is_open)
  end

  def dispatch_async_action(session, node)
    wait_message = node.dig(:data, :wait_message) ||
                   node.dig(:data, :feedback_message) ||
                   '⏳ Aguarde um instante enquanto consultamos seus dados...'

    session.update_context(last_wait_message: wait_message)
    create_outgoing_message(wait_message)

    Custom::Flows::AsyncActionJob.perform_later(session.id, node[:id], node[:data] || {})
  end

  def dispatch_simple_message(session, node)
    msg_text = node.dig(:data, :text)
    session.update_context(last_message_sent: msg_text)
    create_outgoing_message(msg_text)
  end

  def dispatch_interactive(session, node)
    text = node.dig(:data, :text)
    options = node.dig(:data, :buttons) || node.dig(:data, :items) || []
    session.update_context(last_prompt: text)
    return unless session.conversation && text.present?

    Custom::Flows::InteractiveMessageService.dispatch!(session.conversation, text, options)
  end

  def dispatch_ai_fallback(session, node)
    prompt = input_data[:content] || session.context&.dig('last_unmatched_input')
    return trigger_human_handoff(session, node, 'human_intent_detected') if Custom::Ai::HandoffDetectorService.human_intent?(prompt)

    node_data = node[:data] || {}
    result = Custom::Ai::BedrockService.chat(prompt, node_data)
    ai_text = result[:content]

    session.update_context(ai_routed: true, ai_result: result, last_ai_query: prompt, last_ai_response: ai_text)
    create_outgoing_message(ai_text)
  end

  def trigger_human_handoff(session, node, reason)
    team_name = node.dig(:data, :handoff_team) || 'SAC'
    team = session.account.teams.where('lower(name) = ?', team_name.to_s.downcase).first

    config = node[:data] || {}
    result = Custom::Flows::ScheduleEvaluatorService.route_and_handoff!(session.conversation, team, config)
    session.update!(status: :handoff)
    session.update_context(handoff_reason: reason, handoff_result: result)

    handoff_msg = node.dig(:data, :handoff_message) || 'Encaminhando seu atendimento para nossa equipe...'
    create_outgoing_message(handoff_msg)
  end

  def create_outgoing_message(content)
    return unless session.conversation && content.present?

    session.conversation.messages.create!(
      account_id: session.account_id,
      inbox_id: session.conversation.inbox_id,
      message_type: :outgoing,
      content: content
    )
  end
end
