# frozen_string_literal: true

Rails.application.config.to_prepare do
  Contact.prepend(Custom::Concerns::ContactPhoneNormalizer) if defined?(Contact) && !(Contact <= Custom::Concerns::ContactPhoneNormalizer)

  if defined?(ContactInboxWithContactBuilder) &&
     !(ContactInboxWithContactBuilder <= Custom::Concerns::ContactInboxWithContactBuilderExtension)
    ContactInboxWithContactBuilder.prepend(Custom::Concerns::ContactInboxWithContactBuilderExtension)
  end

  if defined?(ContactInboxSourceIdResolver) &&
     !(ContactInboxSourceIdResolver <= Custom::Concerns::ContactInboxSourceIdResolverExtension)
    ContactInboxSourceIdResolver.prepend(Custom::Concerns::ContactInboxSourceIdResolverExtension)
  end

  if defined?(ContactIdentifyAction) &&
     !(ContactIdentifyAction <= Custom::Concerns::ContactIdentifyActionExtension)
    ContactIdentifyAction.prepend(Custom::Concerns::ContactIdentifyActionExtension)
  end
end
