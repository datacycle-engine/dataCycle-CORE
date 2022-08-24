# frozen_string_literal: true

module DataCycleCore
  class SubscriptionMailerJob < ActionMailer::MailDeliveryJob
    include DataCycleCore::JobExtensions::DelayedJob

    queue_as :mailers
    queue_with_reference_id -> { arguments.dig(3, :args, 0)&.id.to_s }
    queue_with_reference_type -> { "#{arguments[0].demodulize.underscore}_#{arguments[1]}" }
  end
end
