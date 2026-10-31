# frozen_string_literal: true

class Custom::Kanban::SyncService
  def self.handle_card_movement(conversation, new_stage_id, stage_name: nil)
    new(conversation, new_stage_id, stage_name: stage_name).handle_card_movement
  end

  def initialize(conversation, new_stage_id, stage_name: nil)
    @conversation = conversation
    @new_stage_id = new_stage_id.to_s
    @stage_name = stage_name
  end

  def handle_card_movement
    active_session = find_active_session
    stage_result = Custom::Kanban::StageService.transition!(@conversation, active_session, @new_stage_id, @stage_name)
    matching_flow = find_matching_flow

    return no_trigger_response(stage_result) unless matching_flow

    session = trigger_flow_execution!(matching_flow, active_session)
    {
      status: 'triggered',
      stage_result: stage_result,
      flow_id: matching_flow.id,
      session_id: session.id
    }
  end

  private

  def find_active_session
    Custom::FlowSession.where(conversation: @conversation).active.last
  end

  def find_matching_flow
    Custom::Flow.published
                .where(account_id: @conversation.account_id)
                .find_by("trigger_type IN ('kanban_stage_entered', 'kanban_stage') AND trigger_config ->> 'stage_id' = ?", @new_stage_id)
  end

  def trigger_flow_execution!(flow, current_active_session)
    current_active_session&.update!(status: :completed)

    session = Custom::FlowSession.create!(
      account: @conversation.account,
      custom_flow: flow,
      conversation: @conversation,
      status: :active,
      context: {
        'trigger' => 'kanban_card_movement',
        'stage_id' => @new_stage_id,
        'stage_name' => @stage_name
      }
    )

    Custom::Flows::ExecutionEngine.process!(session)
    session
  end

  def no_trigger_response(stage_result)
    {
      status: 'no_trigger',
      stage_result: stage_result,
      stage_id: @new_stage_id
    }
  end
end
