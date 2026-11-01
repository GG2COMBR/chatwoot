# frozen_string_literal: true

class Custom::Kanban::StageService
  def self.transition!(conversation, session, stage_id, stage_name = nil)
    new(conversation, session, stage_id, stage_name).transition!
  end

  def self.move_card!(card, new_stage_id, position = nil)
    stage = Custom::KanbanStage.find_by(id: new_stage_id)
    return card unless stage

    card.custom_kanban_stage_id = stage.id
    card.position = position.to_i if position.present?
    card.save!

    if card.conversation
      transition!(card.conversation, nil, stage.id.to_s, stage.name)
    else
      broadcast_card_movement!(card, stage)
    end
    card
  end

  def self.broadcast_card_movement!(card, stage)
    channel = "account_#{card.account_id}"
    payload = {
      event: 'kanban.card_moved',
      data: {
        account_id: card.account_id,
        card_id: card.id,
        board_id: card.custom_kanban_board_id,
        stage_id: stage.id,
        stage_name: stage.name,
        position: card.position,
        updated_at: Time.current.iso8601
      }
    }
    ActionCable.server.broadcast(channel, payload)
    ActionCable.server.broadcast("#{channel}_kanban", payload)
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] Card broadcast failed: #{e.message}")
  end

  def initialize(conversation, session, stage_id, stage_name = nil)
    @conversation = conversation
    @session = session
    @input_stage_id = stage_id.to_s
    @kanban_stage = resolve_kanban_stage
    @stage_id = @kanban_stage&.id&.to_s || @input_stage_id
    @stage_name = stage_name.presence || @kanban_stage&.name || @input_stage_id.humanize
  end

  def transition!
    now = Time.current.iso8601
    dwell = calculate_dwell_time(now)

    card = sync_state!(now, dwell)
    broadcast_transition!(now, dwell, card) if @conversation

    transition_result(now, dwell, card)
  end

  private

  def sync_state!(now, dwell)
    update_conversation! if @conversation
    card = sync_card! if @conversation && @kanban_stage
    update_session!(now, dwell) if @session
    card
  end

  def transition_result(now, dwell, card)
    {
      status: 'success',
      stage_id: @stage_id,
      stage_name: @stage_name,
      kanban_stage_id: @kanban_stage&.id,
      card_id: card&.id,
      updated_at: now,
      dwell_time: dwell
    }
  end

  def resolve_kanban_stage
    return nil unless @conversation&.account_id && @input_stage_id.present?

    stages = Custom::KanbanStage.includes(:custom_kanban_board).where(account_id: @conversation.account_id)
    if @input_stage_id.match?(/\A\d+\z/)
      stages.find_by(id: @input_stage_id)
    else
      stages.find_by(slug: @input_stage_id)
    end
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] Failed to resolve kanban stage: #{e.message}")
    nil
  end

  def calculate_dwell_time(timestamp)
    prev_entered = session_last_entered
    return nil unless prev_entered

    seconds = [0, (Time.iso8601(timestamp) - Time.iso8601(prev_entered)).to_i].max
    minutes = (seconds / 60.0).round(2)
    { seconds: seconds, minutes: minutes }
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] Dwell time calculation failed: #{e.message}")
    nil
  end

  def session_last_entered
    @session&.context&.dig('stage_history')&.last&.dig('entered_at')
  end

  def update_conversation!
    @conversation.custom_kanban_stage_id = @kanban_stage&.id if @kanban_stage

    sync_board_custom_attribute!
    @conversation.save!
  end

  def sync_board_custom_attribute!
    status_key = @kanban_stage&.custom_kanban_board&.status_custom_attribute_key
    return if status_key.blank?

    attributes = (@conversation.custom_attributes || {}).dup
    attributes[status_key] = @stage_name
    @conversation.custom_attributes = attributes
  end

  def update_session!(timestamp, dwell)
    history = (@session.context&.dig('stage_history') || []).map(&:dup)
    if history.any? && dwell
      history.last['exited_at'] = timestamp
      history.last['dwell_time_seconds'] = dwell[:seconds]
      history.last['dwell_time_minutes'] = dwell[:minutes]
    end

    history << {
      'stage_id' => @stage_id,
      'stage_name' => @stage_name,
      'entered_at' => timestamp
    }

    @session.update_context(
      current_kanban_stage_id: @stage_id,
      current_kanban_stage_name: @stage_name,
      stage_history: history
    )
  end

  def sync_card!
    board = @kanban_stage.custom_kanban_board
    card = Custom::KanbanCard.where(conversation_id: @conversation.id, custom_kanban_board_id: board.id).first
    if card
      card.update!(custom_kanban_stage_id: @kanban_stage.id)
    elsif @conversation.contact_id.present?
      card = Custom::KanbanCard.create!(
        account_id: @conversation.account_id,
        custom_kanban_board_id: board.id,
        custom_kanban_stage_id: @kanban_stage.id,
        contact_id: @conversation.contact_id,
        conversation_id: @conversation.id,
        title: @conversation.contact&.name.presence || "Conversa ##{@conversation.display_id}"
      )
    end
    card
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] sync_card! failed: #{e.message}")
    nil
  end

  def broadcast_transition!(timestamp, dwell, card = nil)
    return unless @conversation&.account_id

    channel = "account_#{@conversation.account_id}"
    payload = transition_payload(timestamp, dwell, card)

    ActionCable.server.broadcast(channel, payload)
    ActionCable.server.broadcast("#{channel}_kanban", payload)
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] Broadcast failed: #{e.message}")
  end

  def transition_payload(timestamp, dwell, card)
    {
      event: 'kanban.stage_changed',
      data: {
        account_id: @conversation.account_id,
        conversation_id: @conversation.id,
        card_id: card&.id,
        board_id: @kanban_stage&.custom_kanban_board_id,
        stage_id: @stage_id,
        stage_name: @stage_name,
        kanban_stage_id: @kanban_stage&.id,
        updated_at: timestamp,
        dwell_time: dwell
      }
    }
  end
end
