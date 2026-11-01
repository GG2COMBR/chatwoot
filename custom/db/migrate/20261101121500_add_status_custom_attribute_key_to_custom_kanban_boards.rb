# frozen_string_literal: true

class AddStatusCustomAttributeKeyToCustomKanbanBoards < ActiveRecord::Migration[7.0]
  def change
    add_column :custom_kanban_boards, :status_custom_attribute_key, :string
  end
end
