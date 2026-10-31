# frozen_string_literal: true

class Custom::Flows::EligibilityService
  class << self
    def eligible?(conversation, message = nil)
      return false unless conversation.is_a?(Conversation)
      return false if conversation.assignee_id.present?
      return false if conversation.open?
      return false if invalid_message?(message)
      return false unless active_flow_available?(conversation)

      true
    end

    def handle_human_interruption(conversation)
      return false unless conversation.is_a?(Conversation)

      active_sessions = Custom::FlowSession.where(conversation_id: conversation.id, status: :active)
      return false if active_sessions.empty?

      active_sessions.find_each do |session|
        session.update!(
          status: :interrupted_by_human,
          context: (session.context || {}).merge('interrupted_at' => Time.current.iso8601)
        )
      end

      true
    end

    def handle_human_message(message)
      return false unless message.is_a?(Message)
      return false unless message.outgoing?
      return false unless message.sender.is_a?(User)
      return false if message.private?

      handle_human_interruption(message.conversation)
    end

    def ensure_pending_state_on_reopen(conversation)
      return false unless conversation.is_a?(Conversation)
      return false if conversation.assignee_id.present?

      if conversation.resolved? || conversation.snoozed?
        conversation.update!(status: :pending)
        true
      else
        false
      end
    end

    private

    def invalid_message?(message)
      return false if message.nil?

      !message.incoming? || message.private?
    end

    def active_flow_available?(conversation)
      Custom::Flow.published.exists?(account_id: conversation.account_id)
    end
  end
end
