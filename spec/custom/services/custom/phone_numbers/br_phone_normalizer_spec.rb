# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::PhoneNumbers::BrPhoneNormalizer do
  describe '.normalize_e164' do
    it 'returns nil when phone number is blank' do
      expect(described_class.normalize_e164(nil)).to be_nil
      expect(described_class.normalize_e164('')).to be_nil
      expect(described_class.normalize_e164('   ')).to be_nil
    end

    it 'normalizes an 8-digit Brazilian mobile number to 9-digit format' do
      expect(described_class.normalize_e164('+551187654321')).to eq('+5511987654321')
      expect(described_class.normalize_e164('551198765432')).to eq('+5511998765432')
      expect(described_class.normalize_e164('+554178901234')).to eq('+5541978901234')
      expect(described_class.normalize_e164('+553161234567')).to eq('+5531961234567')
    end

    it 'preserves already normalized 9-digit Brazilian mobile numbers' do
      expect(described_class.normalize_e164('+5511987654321')).to eq('+5511987654321')
      expect(described_class.normalize_e164('5511987654321')).to eq('+5511987654321')
    end

    it 'preserves Brazilian landline numbers starting with 2, 3, 4, 5 without adding a 9' do
      expect(described_class.normalize_e164('+551134567890')).to eq('+551134567890')
      expect(described_class.normalize_e164('+552123456789')).to eq('+552123456789')
      expect(described_class.normalize_e164('+554145678901')).to eq('+554145678901')
      expect(described_class.normalize_e164('+555156789012')).to eq('+555156789012')
    end

    it 'preserves international phone numbers' do
      expect(described_class.normalize_e164('+14155552671')).to eq('+14155552671')
      expect(described_class.normalize_e164('+442071838750')).to eq('+442071838750')
      expect(described_class.normalize_e164('+351912345678')).to eq('+351912345678')
    end
  end

  describe '.e164_variants' do
    it 'returns both 9-digit and 8-digit variants for Brazilian mobile numbers' do
      variants = described_class.e164_variants('+551187654321')
      expect(variants).to contain_exactly('+5511987654321', '+551187654321')

      variants_from_9 = described_class.e164_variants('+5511987654321')
      expect(variants_from_9).to contain_exactly('+5511987654321', '+551187654321')
    end

    it 'returns only the original number for landlines' do
      expect(described_class.e164_variants('+551134567890')).to eq(['+551134567890'])
    end

    it 'returns only the original number for international phones' do
      expect(described_class.e164_variants('+14155552671')).to eq(['+14155552671'])
    end

    it 'returns empty array for blank input' do
      expect(described_class.e164_variants(nil)).to eq([])
      expect(described_class.e164_variants('')).to eq([])
    end
  end

  describe '.source_id_variants' do
    it 'returns raw number variants for WhatsApp wa_id' do
      variants = described_class.source_id_variants('551187654321')
      expect(variants).to contain_exactly('5511987654321', '551187654321')

      variants_from_9 = described_class.source_id_variants('5511987654321')
      expect(variants_from_9).to contain_exactly('5511987654321', '551187654321')
    end

    it 'handles whatsapp: prefix' do
      variants = described_class.source_id_variants('whatsapp:+551187654321')
      expect(variants).to contain_exactly('5511987654321', '551187654321')
    end

    it 'returns single variant for non-Brazilian source_id' do
      expect(described_class.source_id_variants('14155552671')).to eq(['14155552671'])
    end
  end
end
