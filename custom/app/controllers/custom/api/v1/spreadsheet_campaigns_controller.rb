# frozen_string_literal: true

class Custom::Api::V1::SpreadsheetCampaignsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def parse_csv_headers
    content = if params[:file].present?
                params[:file].read
              else
                params[:csv_text].to_s
              end

    if content.blank?
      render json: { error: 'No CSV content provided' }, status: :unprocessable_entity
      return
    end

    reader = Custom::Campaigns::Spreadsheet::CsvReaderService.new(content)
    render json: {
      headers: reader.headers,
      preview: reader.preview_rows(limit: 5)
    }
  end

  def send_test
    inbox = current_account.inboxes.find(params[:inbox_id])
    result = Custom::Campaigns::Spreadsheet::TestSenderService.new(
      inbox: inbox,
      phone_number: params[:phone_number].to_s,
      template_params: params[:template_params]
    ).perform

    if result[:success]
      render json: { success: true, wamid: result[:wamid] }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  def retry_failed
    campaign = current_account.campaigns.find(params[:campaign_id])
    failed_recipients = campaign.custom_campaign_recipients.where(status: 'failed')

    failed_recipients.find_each do |recipient|
      recipient.update!(status: 'pending', error_message: nil)
      Custom::Campaigns::SendSpreadsheetRowJob.perform_later(recipient.id)
    end

    render json: { retried_count: failed_recipients.count }
  end

  def recipients
    campaign = current_account.campaigns.find(params[:campaign_id])
    scope = campaign.custom_campaign_recipients.order(:row_number)
    scope = scope.where(status: params[:status]) if params[:status].present?

    render json: {
      stats: campaign.spreadsheet_stats,
      recipients: scope.limit(100).map do |r|
        {
          id: r.id,
          row_number: r.row_number,
          phone_number: r.phone_number,
          status: r.status,
          error_message: r.error_message,
          message_id: r.message_id,
          sent_at: r.sent_at,
          row_data: r.row_data
        }
      end
    }
  end

  private

  def check_authorization
    authorize :campaign, :show?
  end
end
