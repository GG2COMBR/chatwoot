# frozen_string_literal: true

class CreateCustomKanbanBoardsAndStages < ActiveRecord::Migration[7.0]
  def change
    create_table :custom_kanban_boards do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :custom_kanban_boards, :account_id
    add_index :custom_kanban_boards, %i[account_id position], name: 'idx_custom_boards_on_acc_and_pos'

    create_table :custom_kanban_stages do |t|
      t.bigint :account_id, null: false
      t.bigint :custom_kanban_board_id, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, default: 0, null: false
      t.string :color, default: '#3B82F6'

      t.timestamps
    end

    add_index :custom_kanban_stages, :account_id
    add_index :custom_kanban_stages, :custom_kanban_board_id, name: 'idx_custom_stages_on_board_id'
    add_index :custom_kanban_stages, %i[custom_kanban_board_id slug], unique: true, name: 'idx_custom_stages_on_board_and_slug'
    add_index :custom_kanban_stages, %i[custom_kanban_board_id position], name: 'idx_custom_stages_on_board_and_pos'

    add_column :conversations, :custom_kanban_stage_id, :bigint
    add_index :conversations, :custom_kanban_stage_id
  end
end
