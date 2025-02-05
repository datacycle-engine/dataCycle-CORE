# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemNotificationMailer < ApplicationMailer
    def error_notify(mailing_list, type, external_system, error_message, backtrace)
      return if mailing_list.blank? || type.blank?

      @error_message = error_message
      @backtrace = backtrace
      @external_system = external_system

      mail(
        to: mailing_list,
        subject: "#{@external_system&.name} - #{type} failed multiple times"
      )
    end
  end
end
