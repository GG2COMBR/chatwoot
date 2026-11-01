# frozen_string_literal: true

class CreateCustomKanbanCrmEntities < ActiveRecord::Migration[7.0]
  def change
    create_table :custom_kanban_reasons do |t|
      t.bigint :account_id, null: false
      t.bigint :custom_kanban_board_id, null: false
      t.string :name, null: false
      t.string :reason_type, null: false, default: 'lost'
      t.timestamps
    end
    add_index :custom_kanban_reasons, :account_id
    add_index :custom_kanban_reasons, :custom_kanban_board_id

    create_table :custom_kanban_cards do |t|
      t.bigint :account_id, null: false
      t.bigint :custom_kanban_board_id, null: false
      t.bigint :custom_kanban_stage_id, null: false
      t.bigint :conversation_id
      t.bigint :contact_id, null: false
      t.string :title, null: false
      t.text :description
      t.decimal :value, precision: 12, scale: 2, default: 0.0, null: false
      t.integer :priority, default: 1, null: false
      t.integer :status, default: 0, null: false
      t.bigint :custom_kanban_reason_id
      t.integer :position, default: 0, null: false
      t.datetime :due_at
      t.datetime :scheduled_at
      t.datetime :stage_entered_at
      t.datetime :won_lost_at
      t.timestamps
    end
    add_index :custom_kanban_cards, :account_id
    add_index :custom_kanban_cards, :custom_kanban_board_id
    add_index :custom_kanban_cards, :custom_kanban_stage_id
    add_index :custom_kanban_cards, :conversation_id
    add_index :custom_kanban_cards, :contact_id
    add_index :custom_kanban_cards, :status
    add_index :custom_kanban_cards, %i[custom_kanban_board_id custom_kanban_stage_id position],
              name: 'idx_custom_cards_board_stage_pos'

    create_table :custom_kanban_card_assignees do |t|
      t.bigint :account_id, null: false
      t.bigint :custom_kanban_card_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :custom_kanban_card_assignees, :account_id
    add_index :custom_kanban_card_assignees, %i[custom_kanban_card_id user_id],
              unique: true, name: 'idx_custom_card_assignees_card_user'

    create_table :custom_kanban_card_notes do |t|
      t.bigint :account_id, null: false
      t.bigint :custom_kanban_card_id, null: false
      t.bigint :user_id, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :custom_kanban_card_notes, :account_id
    add_index :custom_kanban_card_notes, :custom_kanban_card_id
  end
end
