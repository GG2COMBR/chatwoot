# frozen_string_literal: true

Rails.application.config.to_prepare do
  if defined?(CannedResponse) &&
     !(CannedResponse <= Custom::Concerns::CannedResponseTeamExtension)
    CannedResponse.include(Custom::Concerns::CannedResponseTeamExtension)
  end

  if defined?(Api::V1::Accounts::CannedResponsesController) &&
     !(Api::V1::Accounts::CannedResponsesController <= Custom::Concerns::CannedResponsesControllerExtension)
    Api::V1::Accounts::CannedResponsesController.prepend(Custom::Concerns::CannedResponsesControllerExtension)
  end
end
