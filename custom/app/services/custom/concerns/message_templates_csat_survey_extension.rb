# frozen_string_literal: true

module Custom::Concerns::MessageTemplatesCsatSurveyExtension
  private

  def content_attributes
    super.merge(
      'assigned_agent_id' => @conversation.assignee_id
    )
  end
end
