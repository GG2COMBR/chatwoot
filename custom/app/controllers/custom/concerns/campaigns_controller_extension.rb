# frozen_string_literal: true

module Custom::Concerns::CampaignsControllerExtension
  extend ActiveSupport::Concern

  private

  def campaign_params
    parse_json_fields_if_needed

    params.require(:campaign).permit(
      :title, :description, :message, :enabled, :trigger_only_during_business_hours,
      :inbox_id, :sender_id, :scheduled_at, :audience_file,
      audience: [:type, :id], trigger_rules: {}, template_params: {}
    )
  end

  def parse_json_fields_if_needed
    %i[template_params audience trigger_rules].each do |field|
      val = params[:campaign]&.dig(field)
      next unless val.is_a?(String)

      params[:campaign][field] = JSON.parse(val)
    rescue JSON::ParserError
      nil
    end
  end
end
