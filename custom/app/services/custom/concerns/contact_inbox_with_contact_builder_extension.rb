# frozen_string_literal: true

module Custom::Concerns::ContactInboxWithContactBuilderExtension
  def find_contact_by_phone_numbers
    candidates = [contact_attributes[:phone_number], *Array(contact_attributes[:phone_number_candidates])].compact_blank.uniq
    expanded_candidates = candidates.flat_map do |num|
      Custom::PhoneNumbers::BrPhoneNormalizer.e164_variants(num)
    end.compact_blank.uniq

    expanded_candidates.each do |phone_number|
      contact = account.contacts.find_by(phone_number: phone_number)
      return contact if contact
    end

    nil
  end
end
