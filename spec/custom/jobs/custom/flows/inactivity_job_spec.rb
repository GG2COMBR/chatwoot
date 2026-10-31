# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::InactivityJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { Account.create!(name: 'GG2 Test Account') }
  let(:flow) do
    Custom::Flow.create!(
      account: account,
      name: 'Inactivity Flow',
      status: :published,
      nodes: [
        {
          id: 'node_menu',
          type: 'interactive_buttons',
          data: {
            text: 'Menu Principal',
            inactivity_timeout: 300,
            inactivity_message: 'Você ainda está aí?',
            farewell_message: 'Atendimento finalizado por inatividade.'
          }
        }
      ],
      edges: []
    )
  end
  let(:conversation) { create(:conversation, account: account) }
  let(:session) do
    Custom::FlowSession.create!(
      account: account,
      custom_flow: flow,
      conversation: conversation,
      status: :active,
      current_node_id: 'node_menu'
    )
  end

  it 'enqueues job in :flows_processing queue' do
    expect(described_class.new.queue_name).to eq('flows_processing')

    ActiveJob::Base.queue_adapter = :test
    expect do
      described_class.perform_later(session.id, 'node_menu', 'test_token')
    end.to have_enqueued_job(described_class).on_queue('flows_processing')
  end

  describe '.schedule_for' do
    it 'generates token and schedules delayed job' do
      ActiveJob::Base.queue_adapter = :test
      node = flow.nodes.first.with_indifferent_access

      expect do
        described_class.schedule_for(session, node)
      end.to have_enqueued_job(described_class).on_queue('flows_processing')

      session.reload
      expect(session.context['inactivity_token']).to be_present
      expect(session.context['inactivity_node_id']).to eq('node_menu')
      expect(session.context['inactivity_warned']).to be false
    end
  end

  describe '#perform' do
    let(:token) { 'secret_token_123' }

    before do
      session.update_context(inactivity_token: token, inactivity_node_id: 'node_menu')
    end

    it 'dispatches reminder message and schedules final check on first warning' do
      expect(Custom::Flows::LockService).to receive(:with_lock).with("session:#{session.id}").and_call_original

      expect do
        described_class.new.perform(session.id, 'node_menu', token)
      end.to change { conversation.messages.count }.by(1)

      expect(conversation.messages.last.content).to eq('Você ainda está aí?')

      session.reload
      expect(session.context['inactivity_warned']).to be true
      expect(session.context['inactivity_token']).not_to eq(token)
      expect(session.status).to eq('active')
    end

    it 'terminates session, sends farewell and marks conversation resolved on final expiration' do
      session.update_context(inactivity_warned: true)

      expect do
        described_class.new.perform(session.id, 'node_menu', token)
      end.to change { conversation.messages.count }.by(1)

      expect(conversation.messages.last.content).to eq('Atendimento finalizado por inatividade.')

      session.reload
      expect(session.status).to eq('timed_out')
      expect(session.context['expiration_reason']).to eq('inactivity_timeout')
      expect(conversation.reload.status).to eq('resolved')
    end

    it 'dispatches CSAT survey and supports snoozed conversation status' do
      session.update!(
        flow_snapshot: {
          'nodes' => [
            {
              id: 'node_menu',
              type: 'interactive_buttons',
              data: {
                farewell_message: 'Até logo!',
                send_csat: true,
                csat_message: 'Avalie nossa URA:',
                final_conversation_status: 'snoozed'
              }
            }
          ]
        }
      )
      session.update_context(inactivity_warned: true)

      expect(Custom::Flows::InteractiveMessageService).to receive(:dispatch!).with(
        conversation,
        'Avalie nossa URA:',
        kind_of(Array)
      )

      described_class.new.perform(session.id, 'node_menu', token)

      expect(session.reload.status).to eq('timed_out')
      expect(conversation.reload.status).to eq('snoozed')
    end

    it 'skips execution if customer moved to another node' do
      session.update!(current_node_id: 'node_other')

      expect do
        described_class.new.perform(session.id, 'node_menu', token)
      end.not_to(change { conversation.messages.count })
    end

    it 'skips execution if inactivity token does not match' do
      expect do
        described_class.new.perform(session.id, 'node_menu', 'different_token')
      end.not_to(change { conversation.messages.count })
    end

    it 'skips execution if session is not active' do
      session.update!(status: :completed)

      expect do
        described_class.new.perform(session.id, 'node_menu', token)
      end.not_to(change { conversation.messages.count })
    end
  end
end
