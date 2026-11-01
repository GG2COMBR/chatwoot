# frozen_string_literal: true

class Custom::KanbanCardNote < ApplicationRecord
  self.table_name = 'custom_kanban_card_notes'

  belongs_to :account
  belongs_to :custom_kanban_card, class_name: 'Custom::KanbanCard'
  belongs_to :user, class_name: '::User'

  validates :content, presence: true

  default_scope { order(created_at: :asc) }
end
