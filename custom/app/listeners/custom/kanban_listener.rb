# frozen_string_literal: true

class Custom::KanbanListener < BaseListener
  def conversation_updated(event)
    conversation = event.data[:conversation]
    return unless conversation.is_a?(Conversation)

    changed_attributes = event.data[:changed_attributes]
    Custom::Kanban::AttributeSyncService.sync_conversation!(conversation, changed_attributes)
  end
end
