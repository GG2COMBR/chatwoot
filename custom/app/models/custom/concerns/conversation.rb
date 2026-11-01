# frozen_string_literal: true

module Custom::Concerns::Conversation
  extend ActiveSupport::Concern

  included do
    belongs_to :custom_kanban_stage,
               class_name: 'Custom::KanbanStage',
               optional: true,
               inverse_of: :conversations

    has_many :custom_kanban_cards,
             class_name: 'Custom::KanbanCard',
             foreign_key: :conversation_id,
             dependent: :nullify
  end
end
