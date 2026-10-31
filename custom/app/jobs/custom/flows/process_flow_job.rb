# frozen_string_literal: true

class Custom::Flows::ProcessFlowJob < ApplicationJob
  queue_as :flows_processing

  def perform(session_id, event_data = {})
    Custom::Flows::LockService.with_lock("session:#{session_id}") do
      session = Custom::FlowSession.find_by(id: session_id)
      return unless session&.active?

      process_step(session, event_data)
    end
  end

  private

  def process_step(session, event_data)
    Custom::Flows::ExecutionEngine.process!(session, event_data)
  end
end
