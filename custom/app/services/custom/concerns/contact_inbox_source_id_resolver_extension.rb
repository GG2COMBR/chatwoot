# frozen_string_literal: true

module Custom::Concerns::ContactInboxSourceIdResolverExtension
  def normalized_source_ids
    base_ids = super
    base_ids.flat_map do |id|
      Custom::PhoneNumbers::BrPhoneNormalizer.source_id_variants(id)
    end.compact_blank.uniq
  end
end
