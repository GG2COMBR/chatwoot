# frozen_string_literal: true

module Custom::Concerns::CsatSurveyServiceExtension
  private

  def csat_already_sent?
    last_csat = conversation.messages.where(content_type: :input_csat).order(:created_at).last
    return false if last_csat.blank?

    if recurring_csat_enabled?
      has_incoming_since_last_csat = conversation.messages.incoming.exists?(['created_at > ?', last_csat.created_at])
      !has_incoming_since_last_csat
    else
      super
    end
  end

  def recurring_csat_enabled?
    inbox.csat_config&.fetch('recurring', true)
  end

  def build_csat_message
    msg = super
    msg.content_attributes = (msg.content_attributes || {}).merge(
      'assigned_agent_id' => conversation.assignee_id
    )
    msg
  end
end
