# frozen_string_literal: true

class AddCrmFieldsToCustomKanbanBoardsAndStages < ActiveRecord::Migration[7.0]
  def change
    add_column :custom_kanban_boards, :auto_create_cards, :boolean, default: false, null: false
    add_column :custom_kanban_boards, :inbox_scope, :string, default: 'all', null: false
    add_column :custom_kanban_boards, :default_stage_id, :bigint
    add_column :custom_kanban_boards, :won_lost_enabled, :boolean, default: true, null: false

    add_column :custom_kanban_stages, :sla_hours, :integer
    add_column :custom_kanban_stages, :description, :text
  end
end
