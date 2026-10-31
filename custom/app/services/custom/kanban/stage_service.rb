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
    dwell = calculate_dwell_time(now)

    update_conversation!(now, dwell) if @conversation
    update_session!(now, dwell) if @session
    broadcast_transition!(now, dwell) if @conversation

    {
      status: 'success',
      stage_id: @stage_id,
      stage_name: @stage_name,
      updated_at: now,
      dwell_time: dwell
    }
  end

  private

  def calculate_dwell_time(timestamp)
    prev_entered = last_entered_timestamp
    return nil unless prev_entered

    seconds = [0, (Time.iso8601(timestamp) - Time.iso8601(prev_entered)).to_i].max
    minutes = (seconds / 60.0).round(2)
    { seconds: seconds, minutes: minutes }
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] Dwell time calculation failed: #{e.message}")
    nil
  end

  def last_entered_timestamp
    session_last_entered || conversation_last_entered
  end

  def session_last_entered
    @session&.context&.dig('stage_history')&.last&.dig('entered_at')
  end

  def conversation_last_entered
    @conversation&.custom_attributes&.dig('kanban_stage_updated_at')
  end

  def update_conversation!(timestamp, dwell)
    attributes = (@conversation.custom_attributes || {}).dup
    attributes['kanban_stage_id'] = @stage_id
    attributes['kanban_stage_name'] = @stage_name
    attributes['kanban_stage_updated_at'] = timestamp

    if dwell
      attributes['kanban_last_stage_dwell_seconds'] = dwell[:seconds]
      attributes['kanban_last_stage_dwell_minutes'] = dwell[:minutes]
    end

    @conversation.custom_attributes = attributes
    @conversation.save!
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

  def broadcast_transition!(timestamp, dwell)
    return unless @conversation&.account_id

    channel = "account_#{@conversation.account_id}_kanban"
    payload = {
      event: 'kanban.stage_changed',
      data: {
        account_id: @conversation.account_id,
        conversation_id: @conversation.id,
        stage_id: @stage_id,
        stage_name: @stage_name,
        updated_at: timestamp,
        dwell_time: dwell
      }
    }

    ActionCable.server.broadcast(channel, payload)
  rescue StandardError => e
    Rails.logger.warn("[Custom::Kanban::StageService] Broadcast failed: #{e.message}")
  end
end
