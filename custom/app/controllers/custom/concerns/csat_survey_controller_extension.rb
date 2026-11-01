# frozen_string_literal: true

module Custom::Concerns::CsatSurveyControllerExtension
  private

  def set_message
    @message = if params[:message_id].present?
                 @conversation.messages.find(params[:message_id])
               else
                 @conversation.messages.where(content_type: 'input_csat').order(:created_at).last!
               end
  end
end
