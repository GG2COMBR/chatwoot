# frozen_string_literal: true

module Custom::Concerns::ContactPhoneNormalizer
  def prepare_contact_attributes
    super
    normalize_br_phone_number
  end

  private

  def normalize_br_phone_number
    return if phone_number.blank?

    normalized = Custom::PhoneNumbers::BrPhoneNormalizer.normalize_e164(phone_number)
    self.phone_number = normalized if normalized.present?
  end
end
