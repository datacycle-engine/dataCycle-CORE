# frozen_string_literal: true

module DataCycleCore
  class MailDeliveryJob < ActionMailer::MailDeliveryJob
    include DataCycleCore::JobExtensions::DelayedJob
    include DataCycleCore::JobExtensions::Callbacks

    ATTEMPTS = 10
    WAIT = :exponentially_longer
    PRIORITY = 5

    queue_as :mailers
    queue_with_priority self::PRIORITY

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      arguments[1]
    end
  end
end
