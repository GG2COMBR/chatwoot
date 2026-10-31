# frozen_string_literal: true

class Custom::Kanban::StageService
  def self.transition!(conversation, session, stage_id, stage_name = nil)
    new(conversation, session, stage_id, stage_name).transition!
  end

  def initialize(conversation, session, stage_id, stage_name = nil)
    @conversation = conversation
    @session = session
    @stage_id = stage_id.to_s
    @stage_name = stage_name.presence || @stage_id.humanize
  end

  def transition!
    now = Time.current.iso8601
    update_conversation!(now) if @conversation
    update_session!(now) if @session
    broadcast_transition!(now) if @conversation

    {
      status: 'success',
      stage_id: @stage_id,
      stage_name: @stage_name,
      updated_at: now
    }
  end

  private

  def update_conversation!(timestamp)
    attributes = (@conversation.custom_attributes || {}).dup
    attributes['kanban_stage_id'] = @stage_id
    attributes['kanban_stage_name'] = @stage_name
    attributes['kanban_stage_updated_at'] = timestamp

    @conversation.custom_attributes = attributes
    @conversation.save!
  end

  def update_session!(timestamp)
    history = (@session.context&.dig('stage_history') || []).dup
    history << {
      stage_id: @stage_id,
      stage_name: @stage_name,
      entered_at: timestamp
    }

    @session.update_context(
      current_kanban_stage_id: @stage_id,
      current_kanban_stage_name: @stage_name,
      stage_history: history
    )
  end

  def broadcast_transition!(timestamp)
    return unless @conversation&.account_id

    channel = "account_#{@conversation.account_id}_kanban"
    payload = {
      event: 'kanban.stage_changed',
      data: {
        account_id: @conversation.account_id,
        conversation_id: @conversation.id,
        stage_id: @stage_id,
        stage_name: @stage_name,
        updated_at: timestamp
      }
    }

    ActionCable.server.broadcast(channel, payload)
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] Broadcast failed: #{e.message}")
  end
end
