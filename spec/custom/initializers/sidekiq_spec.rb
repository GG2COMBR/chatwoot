# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq Custom Queues Configuration', type: :request do
  it 'configures Sidekiq server with flows_processing and campaigns_processing queues' do
    config_mock = Class.new do
      attr_accessor :queues, :default_capsule

      def initialize
        @queues = %w[default critical]
        @default_capsule = OpenStruct.new(queues: %w[default critical])
      end

      def [](key)
        @queues if key == :queues
      end

      def []=(key, value)
        @queues = value if key == :queues
      end
    end.new

    allow(Sidekiq).to receive(:configure_server).and_yield(config_mock)

    # Re-evaluate the initializer logic
    load Rails.root.join('custom/config/initializers/sidekiq.rb')

    expect(config_mock[:queues]).to include('flows_processing', 'campaigns_processing')
    expect(config_mock.default_capsule.queues).to include('flows_processing', 'campaigns_processing')
  end
end
