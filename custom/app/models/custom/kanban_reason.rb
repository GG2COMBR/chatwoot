# frozen_string_literal: true

class Custom::KanbanReason < ApplicationRecord
  self.table_name = 'custom_kanban_reasons'

  belongs_to :account
  belongs_to :custom_kanban_board, class_name: 'Custom::KanbanBoard'
  has_many :custom_kanban_cards,
           class_name: 'Custom::KanbanCard',
           foreign_key: :custom_kanban_reason_id,
           dependent: :nullify

  validates :name, presence: true
  validates :reason_type, inclusion: { in: %w[won lost] }
end
