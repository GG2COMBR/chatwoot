# frozen_string_literal: true

class Custom::KanbanStage < ApplicationRecord
  self.table_name = 'custom_kanban_stages'

  belongs_to :account
  belongs_to :custom_kanban_board,
             class_name: 'Custom::KanbanBoard',
             inverse_of: :custom_kanban_stages

  has_many :conversations,
           class_name: '::Conversation',
           foreign_key: :custom_kanban_stage_id,
           dependent: :nullify,
           inverse_of: :custom_kanban_stage

  has_many :custom_kanban_cards,
           class_name: 'Custom::KanbanCard',
           foreign_key: :custom_kanban_stage_id,
           dependent: :restrict_with_error,
           inverse_of: :custom_kanban_stage

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :custom_kanban_board_id }

  default_scope { order(:position, :name) }
end
