# frozen_string_literal: true

# =============================================================================
# Enterprise Limits Self-Hosted Compatibility Guard
# =============================================================================
# Upstream Chatwoot's frontend calls GET /enterprise/api/v1/accounts/:id/limits
# whenever Enterprise modules are loaded (e.g. useCaptain, Billing, Overview).
# In self-hosted and development environments (DEPLOYMENT_ENV != 'cloud'),
# Enterprise::Api::V1::AccountsController#check_cloud_env blocks this endpoint
# with a 404 Not Found, causing console errors and breaking limit-aware features.
#
# Skipping check_cloud_env for :limits allows the controller to safely execute
# its built-in default_limits fallback, returning 200 OK with valid quota data.
# =============================================================================

Rails.application.config.to_prepare do
  if defined?(Enterprise::Api::V1::AccountsController)
    Enterprise::Api::V1::AccountsController.class_eval do
      skip_before_action :check_cloud_env, only: [:limits], raise: false
    end
  end
end
