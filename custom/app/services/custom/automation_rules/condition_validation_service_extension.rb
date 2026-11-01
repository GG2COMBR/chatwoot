# frozen_string_literal: true

module Custom::AutomationRules::ConditionValidationServiceExtension
  def initialize(rule)
    super
    return if @conversation_filters.blank?

    @conversation_filters['custom_kanban_stage_id'] ||= {
      'attribute_type' => 'standard',
      'data_type' => 'number',
      'filter_operators' => %w[equal_to not_equal_to is_present is_not_present]
    }
  end
end
