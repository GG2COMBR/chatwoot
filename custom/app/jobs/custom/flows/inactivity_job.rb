# frozen_string_literal: true

class Custom::Flows::InactivityJob < ApplicationJob
  queue_as :flows_processing

  DEFAULT_REMINDER_MSG = 'Você ainda está aí? Posso continuar te ajudando?'
  DEFAULT_FAREWELL_MSG = 'Atendimento encerrado por inatividade. Caso precise de algo mais, basta nos enviar uma nova mensagem!'

  def self.schedule_for(session, node)
    return unless session&.active? && node.present?

    token = SecureRandom.hex(8)
    session.update_context(
      inactivity_token: token,
      inactivity_node_id: node[:id],
      inactivity_warned: false
    )

    timeout = (node.dig(:data, :inactivity_timeout) || 300).to_i
    set(wait: timeout.seconds).perform_later(session.id, node[:id], token)
  end

  def perform(session_id, node_id, token)
    Custom::Flows::LockService.with_lock("session:#{session_id}") do
      session = Custom::FlowSession.find_by(id: session_id)
      return unless eligible_for_inactivity?(session, node_id, token)

      handle_inactivity(session, node_id)
    end
  end

  private

  def eligible_for_inactivity?(session, node_id, token)
    return false unless session&.active?
    return false unless session.current_node_id.to_s == node_id.to_s
    return false unless session.context&.dig('inactivity_token') == token

    true
  end

  def handle_inactivity(session, node_id)
    node = session.current_node || {}

    if session.context&.dig('inactivity_warned')
      handle_final_expiration(session, node)
    else
      send_inactivity_warning(session, node, node_id)
    end
  end

  def send_inactivity_warning(session, node, node_id)
    message = node.dig(:data, :inactivity_message) || DEFAULT_REMINDER_MSG
    dispatch_message(session, message)

    next_token = SecureRandom.hex(8)
    session.update_context(
      inactivity_warned: true,
      inactivity_warned_at: Time.current.iso8601,
      inactivity_token: next_token
    )

    timeout = (node.dig(:data, :inactivity_timeout) || 300).to_i
    self.class.set(wait: timeout.seconds).perform_later(session.id, node_id, next_token)
  end

  def handle_final_expiration(session, node)
    farewell = node.dig(:data, :farewell_message) || DEFAULT_FAREWELL_MSG
    dispatch_message(session, farewell)
    send_csat_survey(session, node) if node.dig(:data, :send_csat) == true

    session.update!(status: :timed_out)
    session.update_context(expired_at: Time.current.iso8601, expiration_reason: 'inactivity_timeout')

    target_status = node.dig(:data, :final_conversation_status)
    if target_status.to_s.downcase == 'snoozed'
      session.conversation&.snoozed!
    else
      session.conversation&.resolved!
    end
  end

  def send_csat_survey(session, node)
    prompt = node.dig(:data, :csat_message) || 'Como você avalia nosso atendimento automático?'
    options = [
      { id: 'csat_5', title: '⭐⭐⭐⭐⭐ Excelente' },
      { id: 'csat_3', title: '⭐⭐⭐ Regular' },
      { id: 'csat_1', title: '⭐ Ruim' }
    ]
    Custom::Flows::InteractiveMessageService.dispatch!(session.conversation, prompt, options)
  end

  def dispatch_message(session, content)
    return unless session.conversation && content.present?

    session.conversation.messages.create!(
      account_id: session.account_id,
      inbox_id: session.conversation.inbox_id,
      message_type: :outgoing,
      content: content
    )
  end
end
