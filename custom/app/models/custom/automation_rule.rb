# frozen_string_literal: true

module Custom::AutomationRule
  def actions_attributes
    super + %w[trigger_flow]
  end
end
