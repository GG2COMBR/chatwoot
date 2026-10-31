# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::ProcessFlowJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:flow) { Custom::Flow.create!(account: account, name: 'Flow 1', status: :published) }
  let(:conversation) { create(:conversation, account: account) }
  let(:session) { Custom::FlowSession.create!(account: account, custom_flow: flow, conversation: conversation, status: :active) }

  it 'enqueues job in :flows_processing queue' do
    expect(described_class.new.queue_name).to eq('flows_processing')

    ActiveJob::Base.queue_adapter = :test
    expect do
      described_class.perform_later(session.id)
    end.to have_enqueued_job(described_class).on_queue('flows_processing')
  end

  it 'processes active session while acquiring distributed lock' do
    expect(Custom::Flows::LockService).to receive(:with_lock).with("session:#{session.id}").and_call_original

    result = described_class.new.perform(session.id)
    expect(result).to eq(session)
  end

  it 'skips execution if session is not active' do
    session.update!(status: :completed)

    result = described_class.new.perform(session.id)
    expect(result).to be_nil
  end

  it 'skips execution gracefully if session is not found' do
    result = described_class.new.perform(-999)
    expect(result).to be_nil
  end
end
