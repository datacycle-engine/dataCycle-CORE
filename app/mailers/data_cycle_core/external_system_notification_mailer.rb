# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemNotificationMailer < ApplicationMailer
    def error_notify(mailing_list, trigger, external_source_info = {name: nil}, last_exception = nil)
      return if mailing_list.blank? || trigger.blank? || trigger.nil? || external_source_info.blank? || external_source_info.nil?

      mail(
        to: mailing_list,
        subject: "#{external_source_info[:name]}-#{trigger.capitalize} failed multiple times"
      ) do |format|
        format.text { render plain: last_exception || 'No information about last exception provided' }
      end
    end
  end
end
