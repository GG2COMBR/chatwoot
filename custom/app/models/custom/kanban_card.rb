# frozen_string_literal: true

class Custom::KanbanCard < ApplicationRecord
  self.table_name = 'custom_kanban_cards'

  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }
  enum :status, { open: 0, won: 1, lost: 2 }

  belongs_to :account
  belongs_to :custom_kanban_board, class_name: 'Custom::KanbanBoard'
  belongs_to :custom_kanban_stage, class_name: 'Custom::KanbanStage'
  belongs_to :conversation, class_name: '::Conversation', optional: true
  belongs_to :contact, class_name: '::Contact'
  belongs_to :custom_kanban_reason, class_name: 'Custom::KanbanReason', optional: true

  has_many :custom_kanban_card_assignees,
           class_name: 'Custom::KanbanCardAssignee',
           foreign_key: :custom_kanban_card_id,
           dependent: :destroy
  has_many :assignees, through: :custom_kanban_card_assignees, source: :user

  has_many :custom_kanban_card_notes,
           class_name: 'Custom::KanbanCardNote',
           foreign_key: :custom_kanban_card_id,
           dependent: :destroy

  validates :title, presence: true
  validates :value, numericality: { greater_than_or_equal_to: 0 }

  before_create :set_initial_timestamps
  before_update :track_status_changes

  default_scope { order(:position, :id) }

  private

  def set_initial_timestamps
    self.stage_entered_at ||= Time.current
  end

  def track_status_changes
    if status_changed?
      self.won_lost_at = open? ? nil : Time.current
    end

    return unless custom_kanban_stage_id_changed?

    self.stage_entered_at = Time.current
  end
end
