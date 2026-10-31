# frozen_string_literal: true

class Custom::Flows::LockService
  class LockAcquisitionError < StandardError; end

  DEFAULT_TTL_MS = 10_000 # 10 seconds
  KEY_PREFIX = 'custom:flow_lock'

  RELEASE_SCRIPT = <<~LUA
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end
  LUA

  class << self
    attr_writer :redis

    def redis
      @redis ||= Redis.new(Redis::Config.app)
    end

    def acquire(key, ttl_ms: DEFAULT_TTL_MS)
      token = SecureRandom.uuid
      acquired = redis.set(namespaced_key(key), token, nx: true, px: ttl_ms)
      acquired ? token : nil
    end

    def release(key, token)
      return false if token.blank?

      result = redis.eval(RELEASE_SCRIPT, keys: [namespaced_key(key)], argv: [token])
      result == 1
    end

    def locked?(key)
      redis.exists?(namespaced_key(key))
    end

    def with_lock(key, ttl_ms: DEFAULT_TTL_MS, raise_on_failure: false)
      token = acquire(key, ttl_ms: ttl_ms)

      unless token
        raise LockAcquisitionError, "Unable to acquire lock for key: #{key}" if raise_on_failure

        return nil
      end

      begin
        yield(token)
      ensure
        release(key, token)
      end
    end

    def namespaced_key(key)
      "#{KEY_PREFIX}:#{key}"
    end
  end
end
