# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::AsyncActionJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:flow) do
    Custom::Flow.create!(
      account: account,
      name: 'Async Flow',
      status: :published,
      nodes: [
        {
          id: 'node_async',
          type: 'async_action',
          data: {
            wait_message: '⏳ Aguarde um instante...',
            type: 'mock',
            mock_response: { order_status: 'delivered' }
          }
        },
        {
          id: 'node_done',
          type: 'finish',
          data: {}
        }
      ],
      edges: [
        { id: 'edge_1', source: 'node_async', target: 'node_done', condition: { status: 'success' } }
      ]
    )
  end
  let(:conversation) { create(:conversation, account: account) }
  let(:session) do
    Custom::FlowSession.create!(
      account: account,
      custom_flow: flow,
      conversation: conversation,
      status: :active,
      current_node_id: 'node_async'
    )
  end

  it 'enqueues job in :flows_processing queue' do
    expect(described_class.new.queue_name).to eq('flows_processing')

    ActiveJob::Base.queue_adapter = :test
    expect do
      described_class.perform_later(session.id, 'node_async', { type: 'mock' })
    end.to have_enqueued_job(described_class).on_queue('flows_processing')
  end

  it 'executes mock action and advances the flow session' do
    expect(Custom::Flows::LockService).to receive(:with_lock).with("session:#{session.id}").and_call_original

    described_class.new.perform(
      session.id,
      'node_async',
      { type: 'mock', mock_response: { order_id: 123 } }
    )

    session.reload
    expect(session.context['action_result']['status']).to eq('success')
    expect(session.context['action_result']['data']).to eq('order_id' => 123)
    expect(session.context['last_action_node']).to eq('node_async')
    expect(session.current_node_id).to eq('node_done')
    expect(session.status).to eq('completed')
  end

  it 'handles http action with success' do
    mock_response = instance_double(HTTParty::Response, success?: true, code: 200, parsed_response: { 'ok' => true })
    allow(HTTParty).to receive(:send).with('get', 'https://api.example.com/check', timeout: 5).and_return(mock_response)

    described_class.new.perform(
      session.id,
      'node_async',
      { type: 'http_request', url: 'https://api.example.com/check', method: 'get' }
    )

    session.reload
    expect(session.context['action_result']['status']).to eq('success')
    expect(session.context['action_result']['code']).to eq(200)
    expect(session.context['action_result']['body']).to eq({ 'ok' => true })
  end

  it 'handles http action network error gracefully' do
    allow(HTTParty).to receive(:send).and_raise(StandardError.new('Connection timeout'))

    described_class.new.perform(
      session.id,
      'node_async',
      { type: 'http_request', url: 'https://api.example.com/fail', method: 'get' }
    )

    session.reload
    expect(session.context['action_result']['status']).to eq('error')
    expect(session.context['action_result']['error']).to eq('Connection timeout')
  end

  it 'skips execution if session is not active' do
    session.update!(status: :completed)

    result = described_class.new.perform(session.id, 'node_async', {})
    expect(result).to be_nil
  end

  it 'skips execution if session is not found' do
    result = described_class.new.perform(-999, 'node_async', {})
    expect(result).to be_nil
  end
end
