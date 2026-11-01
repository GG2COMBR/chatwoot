# frozen_string_literal: true

module Custom::Concerns::ContactIdentifyActionExtension
  def existing_phone_number_contact
    return if params[:phone_number].blank?

    @existing_phone_number_contact ||= begin
      variants = Custom::PhoneNumbers::BrPhoneNormalizer.e164_variants(params[:phone_number])
      account.contacts.find_by(phone_number: variants)
    end
  end
end
