# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemNotificationMailer < ApplicationMailer
    def notify(mailing_list, trigger, external_source, last_exception = nil)

      return if mailing_list.blank? || trigger.blank? || trigger.nil?

      binding.pry

      mail(
        to: mailing_list,
        from: 'error-noreply@datacycle.info', # ToDo - replace with correct mail address
        subject: "#{external_source.name}-#{trigger.capitalize} failed multiple times"
      ) do |format|
        format.text { render plain: last_exception || 'No information about last exception provided' }
      end
    end
  end
end
