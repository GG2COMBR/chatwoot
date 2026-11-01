# frozen_string_literal: true

class Custom::Campaigns::Spreadsheet::BatchDispatcherService
  pattr_initialize [:campaign!]

  DEFAULT_INTERVAL_SECONDS = 0.1 # 10 msgs per second rate limit

  def perform
    return unless campaign.audience_file.attached?

    reader = Custom::Campaigns::Spreadsheet::CsvReaderService.from_attachment(campaign.audience_file)
    phone_col = detect_phone_column(reader.headers)
    return mark_campaign_failed('Phone column not found in spreadsheet') if phone_col.blank?

    seen_phones = Set.new
    delay = 0.0

    reader.each_row_with_hash do |row_data, row_number|
      delay = process_row(row_data, row_number, phone_col, seen_phones, delay)
    end

    campaign.completed! if seen_phones.empty?
  end

  private

  def process_row(row_data, row_number, phone_col, seen_phones, delay)
    raw_phone = row_data[phone_col]
    normalized_phone = Custom::PhoneNumbers::BrPhoneNormalizer.normalize_e164(raw_phone)

    if normalized_phone.blank? || !valid_e164?(normalized_phone)
      create_recipient(row_number, raw_phone, row_data, :failed, 'Invalid phone number')
      return delay
    end

    if seen_phones.include?(normalized_phone)
      create_recipient(row_number, normalized_phone, row_data, :skipped, 'Duplicate phone number in spreadsheet')
      return delay
    end

    seen_phones.add(normalized_phone)
    schedule_recipient_job(row_number, normalized_phone, row_data, delay)
  end

  def schedule_recipient_job(row_number, phone, row_data, delay)
    recipient = create_recipient(row_number, phone, row_data, :pending)
    Custom::Campaigns::SendSpreadsheetRowJob.set(wait: delay.seconds).perform_later(recipient.id)
    delay + DEFAULT_INTERVAL_SECONDS
  end

  def valid_e164?(phone)
    phone.match?(/\A\+[1-9]\d{7,14}\z/)
  end

  def create_recipient(row_number, phone, row_data, status, error_message = nil)
    Custom::CampaignRecipient.create!(
      campaign: campaign,
      row_number: row_number,
      phone_number: phone,
      row_data: row_data,
      status: status,
      error_message: error_message
    )
  end

  def detect_phone_column(headers)
    candidates = %w[telefone phone celular whatsapp mobile tel cel]
    headers.find { |h| candidates.include?(h.to_s.strip.downcase) } ||
      campaign.template_params&.dig('phone_column')
  end

  def mark_campaign_failed(reason)
    Rails.logger.error "Campaign #{campaign.id} batch dispatch failed: #{reason}"
    campaign.completed!
  end
end
