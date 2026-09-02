# frozen_string_literal: true

module DataCycleCore
  class MailDeliveryJob < ActionMailer::MailDeliveryJob
    include DataCycleCore::JobExtensions::Callbacks

    queue_as :mailers
    queue_with_priority 5
  end
end
