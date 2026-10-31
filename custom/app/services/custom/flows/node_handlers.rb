# frozen_string_literal: true

module Custom::Flows::NodeHandlers
  def dispatch_team_assignment(session, node)
    team_name = node.dig(:data, :team_name)
    team = session.account.teams.where('lower(name) = ?', team_name.to_s.downcase).first if team_name.present?

    config = node[:data] || {}
    result = Custom::Flows::ScheduleEvaluatorService.route_and_handoff!(session.conversation, team, config)
    session.update!(status: :handoff)
    session.update_context(handoff_result: result)
  end

  def evaluate_business_hours_node(session, node)
    tz = node.dig(:data, :timezone) || 'America/Sao_Paulo'
    is_open = Custom::Flows::ScheduleEvaluatorService.open_now?(node[:data] || session.conversation.inbox, timezone: tz)
    session.update_context(business_hours_open: is_open)
  end

  def dispatch_async_action(session, node)
    wait_message = node.dig(:data, :wait_message) || node.dig(:data, :feedback_message) ||
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
    raw_text = node.dig(:data, :text) || node.dig(:data, :body)
    text = interpolate_variables(raw_text)
    options = node.dig(:data, :buttons) || node.dig(:data, :items) || []
    session.update_context(last_prompt: text)
    return unless session.conversation && text.present?

    Custom::Flows::InteractiveMessageService.dispatch!(session.conversation, text, options)
  end

  def dispatch_ai_fallback(session, node)
    prompt = input_data[:content] || session.context&.dig('last_unmatched_input')
    return trigger_human_handoff(session, node, 'human_intent_detected') if Custom::Ai::HandoffDetectorService.human_intent?(prompt)

    node_data = (node[:data] || {}).dup
    node_data[:system_prompt] = interpolate_variables(node_data[:system_prompt]) if node_data[:system_prompt].present?

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

  def dispatch_kanban_stage_change(session, node)
    stage_id = node.dig(:data, :stage_id) || node.dig(:data, :stage)
    stage_name = node.dig(:data, :stage_name)

    result = Custom::Kanban::StageService.transition!(session.conversation, session, stage_id, stage_name)
    session.update_context(last_kanban_transition: result)
  end

  def finish_node(session, node)
    msg = node.dig(:data, :text) || node.dig(:data, :farewell_message)
    create_outgoing_message(msg) if msg.present?

    session.update!(status: :completed)
    session.update_context(completed_at: Time.current.iso8601)

    target_status = node.dig(:data, :final_conversation_status)
    if target_status.to_s.downcase == 'snoozed'
      session.conversation&.snoozed!
    else
      session.conversation&.resolved!
    end
  end

  def create_outgoing_message(content)
    return unless session.conversation && content.present?

    interpolated_content = interpolate_variables(content)

    session.conversation.messages.create!(
      account_id: session.account_id,
      inbox_id: session.conversation.inbox_id,
      message_type: :outgoing,
      content: interpolated_content
    )
  end

  def interpolate_variables(text)
    return text if text.blank? || session.conversation.blank?

    contact = session.conversation.contact
    contact_replacements(contact).reduce(text.to_s) do |result, (tag, val)|
      result.gsub(tag, val)
    end
  end

  def contact_replacements(contact)
    full_name = contact&.name.presence || 'Cliente'
    {
      '{{contact.name}}' => full_name, '{{contact.first_name}}' => full_name.split(/\s+/).first || 'Cliente',
      '{{contact.email}}' => contact&.email.to_s, '{{contact.phone_number}}' => contact&.phone_number.to_s,
      '{{account.name}}' => session.account&.name.to_s
    }
  end
end
