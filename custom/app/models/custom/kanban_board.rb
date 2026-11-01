# frozen_string_literal: true

class Custom::KanbanBoard < ApplicationRecord
  self.table_name = 'custom_kanban_boards'

  belongs_to :account
  has_many :custom_kanban_stages,
           class_name: 'Custom::KanbanStage',
           foreign_key: :custom_kanban_board_id,
           dependent: :destroy,
           inverse_of: :custom_kanban_board

  validates :name, presence: true

  default_scope { order(:position, :name) }
end
