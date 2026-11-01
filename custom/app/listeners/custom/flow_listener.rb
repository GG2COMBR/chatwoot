# frozen_string_literal: true

class Custom::FlowListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message.is_a?(Message)

    if human_agent_outgoing?(message)
      Custom::Flows::EligibilityService.handle_human_message(message)
    elsif customer_incoming?(message)
      handle_customer_flow_reply(message)
    end
  end

  def conversation_updated(event)
    conversation = event.data[:conversation]
    return unless conversation.is_a?(Conversation)
    return if conversation.assignee_id.blank?

    Custom::Flows::EligibilityService.handle_human_interruption(conversation)
  end

  private

  def human_agent_outgoing?(message)
    message.outgoing? && message.sender.is_a?(User) && !message.private?
  end

  def customer_incoming?(message)
    message.incoming? && !message.private?
  end

  def handle_customer_flow_reply(message)
    conversation = message.conversation
    return unless conversation.is_a?(Conversation)
    return if conversation.assignee_id.present?

    session = Custom::FlowSession.where(conversation: conversation, status: :active).last
    return unless session

    Custom::Flows::ProcessFlowJob.perform_later(session.id, {
                                                  message_id: message.id,
                                                  content: message.content,
                                                  content_type: message.content_type,
                                                  content_attributes: message.content_attributes
                                                })
  end
end
