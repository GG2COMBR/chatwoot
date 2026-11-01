# frozen_string_literal: true

module Custom::AutomationRule
  def conditions_attributes
    super + %w[custom_kanban_stage_id]
  end

  def actions_attributes
    super + %w[trigger_flow]
  end
end
