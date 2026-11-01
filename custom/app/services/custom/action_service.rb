# frozen_string_literal: true

module Custom::ActionService
  def trigger_flow(flow_ids)
    flow_id = flow_ids.is_a?(Array) ? flow_ids.first : flow_ids
    return if flow_id.blank?

    flow = Custom::Flow.where(account_id: @account.id).published.find_by(id: flow_id)
    return log_missing_flow(flow_id) unless flow

    start_conversation_flow_session(flow)
  end

  private

  def log_missing_flow(flow_id)
    Rails.logger.warn("[Custom::ActionService] Flow #{flow_id} not found or not published for account #{@account.id}")
  end

  def start_conversation_flow_session(flow)
    Custom::Flows::LockService.with_lock("conversation:#{@conversation.id}:flow_trigger") do
      complete_previous_active_sessions(flow.id)

      session = Custom::FlowSession.create!(
        account: @account,
        custom_flow: flow,
        conversation: @conversation,
        status: :active
      )

      Custom::Flows::ExecutionEngine.process!(session)
    end
  end

  def complete_previous_active_sessions(flow_id)
    Custom::FlowSession.where(conversation: @conversation, status: :active).find_each do |prev_session|
      prev_session.update!(
        status: :completed,
        context: (prev_session.context || {}).merge('replaced_by_flow_id' => flow_id, 'closed_at' => Time.current.iso8601)
      )
    end
  end
end
