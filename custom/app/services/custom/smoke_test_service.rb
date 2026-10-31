# frozen_string_literal: true

class Custom::SmokeTestService
  def self.healthy?
    true
  end

  def self.layer_info
    {
      layer: 'custom',
      status: 'active',
      autoload: 'zeitwerk'
    }
  end
end
