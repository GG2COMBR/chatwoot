# frozen_string_literal: true

if defined?(Sidekiq)
  Sidekiq.configure_server do |config|
    if config.respond_to?(:default_capsule) && config.default_capsule
      current_queues = config.default_capsule.queues || []
      config.default_capsule.queues = current_queues + ['flows_processing'] unless current_queues.include?('flows_processing')
    end

    queues = config[:queues] || []
    config[:queues] = queues + ['flows_processing'] unless queues.include?('flows_processing')

    Sidekiq.logger.info('[GG2 Custom] Dedicated queue :flows_processing registered successfully in Sidekiq server.')
  end
end
