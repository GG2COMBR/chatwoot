# frozen_string_literal: true

Rails.application.config.to_prepare do
  if defined?(AutomationRules::ConditionsFilterService)
    AutomationRules::ConditionsFilterService.prepend(Custom::AutomationRules::ConditionsFilterServiceExtension)
  end

  if defined?(AutomationRules::ConditionValidationService)
    AutomationRules::ConditionValidationService.prepend(Custom::AutomationRules::ConditionValidationServiceExtension)
  end
end
