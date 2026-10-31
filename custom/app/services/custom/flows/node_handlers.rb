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

  def finish_node(session, _node)
    session.update!(status: :completed)
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
