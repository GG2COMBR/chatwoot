# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Flows::LockService do
  let(:key) { "session:test_#{SecureRandom.hex(4)}" }
  let(:redis) { described_class.redis }

  after do
    redis.del(described_class.namespaced_key(key))
  end

  describe '.acquire and .release' do
    it 'acquires lock and returns unique token' do
      token = described_class.acquire(key, ttl_ms: 5000)

      expect(token).to be_present
      expect(described_class.locked?(key)).to be true
      expect(redis.get(described_class.namespaced_key(key))).to eq(token)
    end

    it 'fails to acquire if already locked' do
      first_token = described_class.acquire(key, ttl_ms: 5000)
      expect(first_token).to be_present

      second_token = described_class.acquire(key, ttl_ms: 5000)
      expect(second_token).to be_nil
    end

    it 'releases lock cleanly with the valid token' do
      token = described_class.acquire(key, ttl_ms: 5000)
      released = described_class.release(key, token)

      expect(released).to be true
      expect(described_class.locked?(key)).to be false
    end

    it 'does not release lock if token does not match' do
      token = described_class.acquire(key, ttl_ms: 5000)
      released = described_class.release(key, 'wrong_token')

      expect(released).to be false
      expect(described_class.locked?(key)).to be true
      expect(redis.get(described_class.namespaced_key(key))).to eq(token)
    end
  end

  describe '.with_lock' do
    it 'executes block within lock and releases automatically' do
      executed = false

      result = described_class.with_lock(key) do |token|
        executed = true
        expect(described_class.locked?(key)).to be true
        expect(token).to be_present
        :success
      end

      expect(executed).to be true
      expect(result).to eq(:success)
      expect(described_class.locked?(key)).to be false
    end

    it 'releases lock even if exception is raised inside block' do
      expect do
        described_class.with_lock(key) do
          raise StandardError, 'simulated block failure'
        end
      end.to raise_error(StandardError, 'simulated block failure')

      expect(described_class.locked?(key)).to be false
    end

    it 'returns nil when lock cannot be acquired' do
      described_class.acquire(key, ttl_ms: 5000)

      executed = false
      result = described_class.with_lock(key) do
        executed = true
      end

      expect(result).to be_nil
      expect(executed).to be false
    end

    it 'raises LockAcquisitionError when raise_on_failure: true' do
      described_class.acquire(key, ttl_ms: 5000)

      expect do
        described_class.with_lock(key, raise_on_failure: true) do
          # unreachable
        end
      end.to raise_error(Custom::Flows::LockService::LockAcquisitionError)
    end
  end
end
