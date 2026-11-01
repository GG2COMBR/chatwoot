# frozen_string_literal: true

class Custom::Kanban::AttributeSyncService
  def self.sync_conversation!(conversation, changed_attributes = nil)
    new(conversation, changed_attributes).sync!
  end

  def initialize(conversation, changed_attributes = nil)
    @conversation = conversation
    @changed_attributes = changed_attributes
  end

  def sync!
    return unless @conversation&.account_id && @conversation.custom_attributes.present?

    boards = Custom::KanbanBoard.where(account_id: @conversation.account_id)
                                .where.not(status_custom_attribute_key: [nil, ''])

    boards.find_each do |board|
      sync_board!(board)
    end
  end

  private

  def sync_board!(board)
    key = board.status_custom_attribute_key
    target_value = @conversation.custom_attributes[key]
    return if target_value.blank?

    stage = find_stage_for_board(board, target_value)
    return unless stage

    update_or_create_card!(board, stage)
  end

  def find_stage_for_board(board, value)
    val_str = value.to_s.strip
    board.custom_kanban_stages.find_by(name: val_str) ||
      board.custom_kanban_stages.find_by(slug: val_str.parameterize.underscore)
  end

  def update_or_create_card!(board, stage)
    card = Custom::KanbanCard.find_by(conversation_id: @conversation.id, custom_kanban_board_id: board.id)
    if card
      return if card.custom_kanban_stage_id == stage.id

      card.update!(custom_kanban_stage_id: stage.id)
      Custom::Kanban::StageService.broadcast_card_movement!(card, stage)
    elsif @conversation.contact_id.present?
      create_and_broadcast_card!(board, stage)
    end
  end

  def create_and_broadcast_card!(board, stage)
    card = Custom::KanbanCard.create!(
      account_id: @conversation.account_id,
      custom_kanban_board_id: board.id,
      custom_kanban_stage_id: stage.id,
      contact_id: @conversation.contact_id,
      conversation_id: @conversation.id,
      title: @conversation.contact&.name.presence || "Conversa ##{@conversation.display_id}"
    )
    Custom::Kanban::StageService.broadcast_card_movement!(card, stage)
  end
end
