# frozen_string_literal: true

module Custom::PhoneNumbers::BrPhoneNormalizer
  module_function

  def normalize_e164(phone_number)
    return if phone_number.blank?

    normalized = normalize_e164_format(phone_number)
    return normalized unless brazil_number?(normalized)

    canonical_mobile_variant(normalized)
  end

  def e164_variants(phone_number)
    normalized = normalize_e164(phone_number)
    return [] if normalized.blank?
    return [normalized] unless brazil_number?(normalized)

    ddd, subscriber = brazil_parts(normalized)
    return [normalized] unless candidate_for_variants?(ddd, subscriber)

    build_mobile_variants(normalized, ddd, subscriber)
  end

  def candidate_for_variants?(ddd, subscriber)
    ddd.present? && subscriber.present? && mobile_candidate_subscriber?(subscriber)
  end

  def build_mobile_variants(normalized, ddd, subscriber)
    with_nine = subscriber.start_with?('9') ? normalized : "+55#{ddd}9#{subscriber}"
    without_nine = subscriber.start_with?('9') ? "+55#{ddd}#{subscriber[1..]}" : normalized

    [with_nine, without_nine].uniq
  end

  def source_id_variants(source_id)
    return [] if source_id.blank?

    raw = source_id.to_s.delete('+').delete_prefix('whatsapp:')
    return [source_id.to_s] unless raw.match?(/\A55\d+\z/)

    variants = e164_variants("+#{raw}")
    variants.map { |v| v.delete('+') }
  end

  def normalize_e164_format(phone_number)
    value = phone_number.to_s.strip
    return if value.blank?

    value.start_with?('+') ? value : "+#{value}"
  end

  def canonical_mobile_variant(phone_number)
    ddd, subscriber = brazil_parts(phone_number)
    return phone_number if ddd.blank? || subscriber.blank?
    return phone_number unless subscriber.length == 8 && mobile_candidate_subscriber?(subscriber)

    "+55#{ddd}9#{subscriber}"
  end

  def brazil_number?(phone_number)
    phone_number.to_s.match?(/\A\+55\d+\z/)
  end

  def brazil_parts(phone_number)
    digits = phone_number.to_s.delete_prefix('+')
    ddd = digits[2, 2]
    subscriber = digits[4..]
    [ddd, subscriber]
  end

  def mobile_candidate_subscriber?(subscriber)
    return false if subscriber.blank?
    return false unless [8, 9].include?(subscriber.length)

    first_digit = subscriber[0]
    if subscriber.length == 8
      first_digit.match?(/[6-9]/)
    else
      subscriber.start_with?('9') && subscriber[1].to_s.match?(/[6-9]/)
    end
  end
end
