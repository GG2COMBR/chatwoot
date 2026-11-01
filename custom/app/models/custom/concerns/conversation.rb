# frozen_string_literal: true

module Custom::Concerns::Conversation
  extend ActiveSupport::Concern

  included do
    belongs_to :custom_kanban_stage,
               class_name: 'Custom::KanbanStage',
               optional: true,
               inverse_of: :conversations
  end
end
