# frozen_string_literal: true

Rails.application.routes.draw do
  scope 'api/v1/accounts/:account_id', module: 'custom/api/v1', as: 'custom_api_v1_account' do
    resources :custom_flows, controller: 'flows' do
      member do
        post :publish
        post :duplicate
      end
    end
  end
end
