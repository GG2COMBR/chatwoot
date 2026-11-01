# frozen_string_literal: true

module Custom::Concerns::CsatSurveyResponseBuilderExtension
  private

  def process_csat_response(conversation, rating, feedback_message)
    resolved_agent_id = message.content_attributes['assigned_agent_id'].presence || conversation.assignee_id
    resolved_agent = conversation.account.users.find_by(id: resolved_agent_id) if resolved_agent_id.present?

    csat_survey_response = message.csat_survey_response || CsatSurveyResponse.new(
      message_id: message.id,
      account_id: message.account_id,
      conversation_id: message.conversation_id,
      contact_id: conversation.contact_id,
      assigned_agent: resolved_agent
    )
    csat_survey_response.rating = rating
    csat_survey_response.feedback_message = feedback_message
    csat_survey_response.assigned_agent ||= resolved_agent if resolved_agent
    csat_survey_response.save!
    csat_survey_response
  end
end
