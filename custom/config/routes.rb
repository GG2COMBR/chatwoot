# frozen_string_literal: true

Rails.application.routes.draw do
  scope 'api/v1/accounts/:account_id', module: 'custom/api/v1', as: 'custom_api_v1_account' do
    resources :custom_flows, controller: 'flows' do
      collection do
        get :kanban_options
      end
      member do
        post :publish
        post :duplicate
      end
    end

    scope module: 'kanban', as: 'kanban' do
      resources :kanban_boards, controller: 'boards' do
        resources :stages, controller: 'stages' do
          collection do
            post :reorder
          end
        end
        resources :cards, controller: 'cards' do
          member do
            post :move
          end
          resources :notes, controller: 'card_notes', only: %i[index create destroy]
        end
        resources :reasons, controller: 'reasons', only: %i[index create destroy]
      end

      resources :kanban_cards, controller: 'cards', only: %i[show update destroy] do
        member do
          post :move
        end
        resources :notes, controller: 'card_notes', only: %i[index create destroy]
      end
    end
  end
end
