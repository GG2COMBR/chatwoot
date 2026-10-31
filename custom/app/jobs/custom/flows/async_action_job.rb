# frozen_string_literal: true

class Custom::Flows::AsyncActionJob < ApplicationJob
  queue_as :flows_processing

  def perform(session_id, node_id, action_config = {})
    Custom::Flows::LockService.with_lock("session:#{session_id}") do
      session = Custom::FlowSession.find_by(id: session_id)
      return unless session&.active?

      result = execute_action(session, action_config)
      session.update_context(action_result: result, last_action_node: node_id)

      # Resume flow execution on the next node with action result
      Custom::Flows::ExecutionEngine.process!(
        session,
        content: result[:status] || 'success',
        action_result: result
      )
    end
  end

  private

  def execute_action(_session, action_config)
    action_type = (action_config[:type] || action_config['type']).to_s

    case action_type
    when 'ecommerce_mock', 'mock_erp', 'mock'
      Custom::Mocks::EcommerceMockService.dispatch(action_config)
    when 'http_request'
      execute_http_action(action_config)
    else
      { status: 'success', data: { processed_at: Time.current.iso8601 } }
    end
  rescue StandardError => e
    { status: 'error', error: e.message }
  end

  def execute_http_action(action_config)
    url = action_config[:url] || action_config['url']
    method = (action_config[:method] || 'get').to_s.downcase

    response = HTTParty.send(method, url, timeout: 5)
    { status: response.success? ? 'success' : 'failed', code: response.code, body: response.parsed_response }
  end
end
