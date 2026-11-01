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

    if session.current_node_id.blank?
      start_flow!
    else
      current_node = find_node(session.current_node_id)
      if current_node && PASS_THROUGH_NODES.include?(current_node[:type].to_s)
        execute_node(current_node)
      else
        advance_flow!
      end
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

    # Se estiver em nó de Slot Filling e ainda estiver coletando campos, re-executa a IA
    if current_node[:type].to_s == 'ai_agent' && current_node.dig(:data, :extract_slots) == true
      execute_node(current_node)
      return if session.context&.dig('slot_filling_status') == 'in_progress'
    end

    next_node = find_next_node(current_node[:id])

    if next_node
      session.update_context(retries: 0)
      session.current_node_id = next_node[:id]
      execute_node(next_node)
    else
      handle_unmatched_transition(current_node)
    end
  end

  def handle_global_escape!(current_node)
    handoff_node = nodes.find { |n| %w[human_transfer team_assignment].include?(n[:type].to_s) }
    if handoff_node
      session.current_node_id = handoff_node[:id]
      execute_node(handoff_node)
    else
      trigger_human_handoff(session, current_node, 'global_escape_requested')
    end
  end

  ESCAPE_KEYWORDS = %w[sair cancelar atendente humano menu].freeze
  PASS_THROUGH_NODES = %w[kanban_stage_change manage_labels condition_router try_catch].freeze

  def global_escape_intent?
    text = input_data[:content].to_s.strip.downcase
    return false if text.blank?

    ESCAPE_KEYWORDS.any? { |kw| text.match?(/\b#{Regexp.escape(kw)}\b/i) }
  end

  def execute_node(node)
    track_node_status_and_dwell_time!(node)
    handler = node_handlers[node[:type].to_s]
    send(handler, session, node) if handler
    schedule_inactivity_monitor(node)

    # Nós de processamento interno avançam automaticamente para a próxima etapa conectada
    if PASS_THROUGH_NODES.include?(node[:type].to_s) && session.active?
      auto_advance_pass_through!(node)
    end
  end

  def auto_advance_pass_through!(node)
    next_node = find_next_node(node[:id])
    return unless next_node

    session.current_node_id = next_node[:id]
    session.save!
    execute_node(next_node)
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

    cond = condition.with_indifferent_access

    button_matches?(cond[:button_id]) ||
      value_matches?(cond[:value]) ||
      status_matches?(cond[:status]) ||
      context_status_matches?(cond[:status]) ||
      keyword_matches?(cond[:keyword])
  end

  def button_matches?(expected)
    expected.present? && expected.to_s == input_data[:button_id].to_s
  end

  def value_matches?(expected)
    expected.present? && expected.to_s.casecmp(input_data[:content].to_s.strip).zero?
  end
  alias status_matches? value_matches?

  def context_status_matches?(expected)
    return false if expected.blank?

    ctx = (session.context || {}).with_indifferent_access
    exp_str = expected.to_s

    exp_str == ctx[:last_try_catch_status].to_s ||
      exp_str == ctx.dig(:last_condition_evaluation, :result).to_s ||
      exp_str == ctx[:slot_filling_status].to_s ||
      exp_str == input_data[:status].to_s
  end

  def keyword_matches?(expected)
    expected.present? && input_data[:content].to_s.downcase.include?(expected.to_s.downcase)
  end

  def track_node_status_and_dwell_time!(node)
    now = Time.current.iso8601
    status_attr_key = session.custom_flow&.trigger_config&.dig('status_custom_attribute_key') ||
                      session.flow_snapshot&.dig('status_custom_attribute_key')

    step_status_value = node.dig(:data, :step_status_value) || node.dig(:data, :status_value)

    if status_attr_key.present? && step_status_value.present? && session.conversation
      attrs = (session.conversation.custom_attributes || {}).dup
      attrs[status_attr_key.to_s] = step_status_value
      session.conversation.custom_attributes = attrs
      session.conversation.save!
    end

    history = (session.context&.dig('step_history') || []).map(&:dup)
    dwell = nil
    if history.any?
      prev = history.last
      prev_entered = prev['entered_at']
      if prev_entered
        secs = [0, (Time.iso8601(now) - Time.iso8601(prev_entered)).to_i].max
        dwell = { seconds: secs, minutes: (secs / 60.0).round(2) }
        prev['exited_at'] = now
        prev['dwell_time_seconds'] = dwell[:seconds]
        prev['dwell_time_minutes'] = dwell[:minutes]
      end
    end

    history << {
      'node_id' => node[:id],
      'node_type' => node[:type],
      'step_status' => step_status_value,
      'entered_at' => now
    }

    session.update_context(
      current_step_status: step_status_value,
      last_step_dwell_time: dwell,
      step_history: history
    )
  rescue StandardError => e
    Rails.logger.warn("[Custom::Flows::ExecutionEngine] Failed to track step dwell time: #{e.message}")
  end

  def schedule_inactivity_monitor(node)
    return unless session.active?
    return if %w[finish team_assignment human_transfer].include?(node[:type].to_s)

    Custom::Flows::InactivityJob.schedule_for(session, node)
  end

  def node_handlers
    {
      'message' => :dispatch_simple_message,
      'interactive_buttons' => :dispatch_interactive,
      'interactive_list' => :dispatch_interactive,
      'team_assignment' => :dispatch_team_assignment,
      'human_transfer' => :dispatch_team_assignment,
      'business_hours' => :evaluate_business_hours_node,
      'async_action' => :dispatch_async_action,
      'async_api' => :dispatch_async_action,
      'ai_fallback' => :dispatch_ai_fallback,
      'ai_agent' => :dispatch_ai_fallback,
      'kanban_stage_change' => :dispatch_kanban_stage_change,
      'try_catch' => :dispatch_try_catch,
      'manage_labels' => :dispatch_manage_labels,
      'condition_router' => :dispatch_condition_router,
      'finish' => :finish_node
    }
  end

  def handle_unmatched_transition(current_node)
    if global_escape_intent?
      handle_global_escape!(current_node)
      return
    end

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
