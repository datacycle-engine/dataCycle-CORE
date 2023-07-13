# frozen_string_literal: true

module DataCycleCore
  class UserRegistrationMailer < ApplicationMailer
    def notify(emails, new_user)
      return if emails.blank?

      @resource = new_user
      @locale = DataCycleCore.ui_locales.first

      mail(to: emails, subject: t('feature.user_registration.mailer.subject', locale: @locale))
    end
  end
end
