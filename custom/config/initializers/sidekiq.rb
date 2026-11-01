# frozen_string_literal: true

if defined?(Sidekiq)
  Sidekiq.configure_server do |config|
    custom_queues = %w[flows_processing campaigns_processing].freeze

    if config.respond_to?(:default_capsule) && config.default_capsule
      current_queues = config.default_capsule.queues || []
      config.default_capsule.queues = (current_queues + custom_queues).uniq
    end

    queues = config[:queues] || []
    config[:queues] = (queues + custom_queues).uniq

    Sidekiq.logger.info("[GG2 Custom] Dedicated queues #{custom_queues.join(', ')} registered successfully in Sidekiq server.")
  end
end
