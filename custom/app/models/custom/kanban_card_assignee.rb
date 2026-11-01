# frozen_string_literal: true

class Custom::KanbanCardAssignee < ApplicationRecord
  self.table_name = 'custom_kanban_card_assignees'

  belongs_to :account
  belongs_to :custom_kanban_card, class_name: 'Custom::KanbanCard'
  belongs_to :user, class_name: '::User'

  validates :user_id, uniqueness: { scope: :custom_kanban_card_id }

  before_validation :set_account, on: :create

  private

  def set_account
    self.account_id ||= custom_kanban_card&.account_id
  end
end
