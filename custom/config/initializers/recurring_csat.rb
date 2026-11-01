# frozen_string_literal: true

Rails.application.config.to_prepare do
  if defined?(CsatSurveyService) &&
     !(CsatSurveyService <= Custom::Concerns::CsatSurveyServiceExtension)
    CsatSurveyService.prepend(Custom::Concerns::CsatSurveyServiceExtension)
  end

  if defined?(CsatSurveys::ResponseBuilder) &&
     !(CsatSurveys::ResponseBuilder <= Custom::Concerns::CsatSurveyResponseBuilderExtension)
    CsatSurveys::ResponseBuilder.prepend(Custom::Concerns::CsatSurveyResponseBuilderExtension)
  end

  if defined?(MessageTemplates::Template::CsatSurvey) &&
     !(MessageTemplates::Template::CsatSurvey <= Custom::Concerns::MessageTemplatesCsatSurveyExtension)
    MessageTemplates::Template::CsatSurvey.prepend(Custom::Concerns::MessageTemplatesCsatSurveyExtension)
  end

  if defined?(Public::Api::V1::CsatSurveyController) &&
     !(Public::Api::V1::CsatSurveyController <= Custom::Concerns::CsatSurveyControllerExtension)
    Public::Api::V1::CsatSurveyController.prepend(Custom::Concerns::CsatSurveyControllerExtension)
  end
end
