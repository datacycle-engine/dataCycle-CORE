# frozen_string_literal: true

module DataCycleCore
  class ApplicationMailer < ActionMailer::Base
    self.delivery_job = DataCycleCore::MailDeliveryJob
  end
end
