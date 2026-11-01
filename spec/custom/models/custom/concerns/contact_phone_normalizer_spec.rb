# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::Concerns::ContactPhoneNormalizer do
  let(:account) { create(:account) }

  describe 'Contact model normalization' do
    it 'automatically normalizes 8-digit mobile phone to 9 digits before validation' do
      contact = build(:contact, account: account, phone_number: '+551187654321')
      contact.valid?
      expect(contact.phone_number).to eq('+5511987654321')
    end

    it 'preserves 9-digit mobile phone' do
      contact = build(:contact, account: account, phone_number: '+5511987654321')
      contact.valid?
      expect(contact.phone_number).to eq('+5511987654321')
    end

    it 'preserves landline without adding 9' do
      contact = build(:contact, account: account, phone_number: '+551134567890')
      contact.valid?
      expect(contact.phone_number).to eq('+551134567890')
    end

    it 'preserves international number' do
      contact = build(:contact, account: account, phone_number: '+14155552671')
      contact.valid?
      expect(contact.phone_number).to eq('+14155552671')
    end
  end

  describe 'ContactInboxWithContactBuilder matching across 8 and 9 digits' do
    let(:inbox) { create(:inbox, account: account) }

    it 'finds existing contact when searching by 9-digit variant and contact was saved with 8 digits' do
      # Simulate a legacy contact saved with 8 digits (skipping validation to emulate legacy record)
      legacy_contact = build(:contact, account: account)
      legacy_contact.phone_number = '+551187654321'
      legacy_contact.save!(validate: false)

      builder = ContactInboxWithContactBuilder.new(
        source_id: '5511987654321',
        inbox: inbox,
        contact_attributes: { phone_number: '+5511987654321' }
      )

      found_contact = builder.send(:find_contact_by_phone_numbers)
      expect(found_contact).to eq(legacy_contact)
    end
  end

  describe 'ContactInboxSourceIdResolver matching across 8 and 9 digits' do
    let(:inbox) { create(:inbox, account: account) }
    let(:contact) { create(:contact, account: account, phone_number: '+5511987654321') }

    it 'reuses existing contact_inbox when incoming message has 9 digits and inbox had 8 digits' do
      existing_contact_inbox = create(
        :contact_inbox,
        contact: contact,
        inbox: inbox,
        source_id: '551187654321'
      )

      resolver = ContactInboxSourceIdResolver.new(
        inbox: inbox,
        source_ids: ['5511987654321'],
        contact_attributes: { phone_number: '+5511987654321' }
      )

      resolved = resolver.perform
      expect(resolved).to eq(existing_contact_inbox)
    end
  end
end
