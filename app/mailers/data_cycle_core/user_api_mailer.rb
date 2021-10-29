# frozen_string_literal: true

module DataCycleCore
  class UserApiMailer < ApplicationMailer
    def notify(emails, new_user)
      return if emails.blank?

      @new_user = new_user
      @locale = DataCycleCore.ui_locales.first

      mail(to: emails, subject: t('feature.user_api.mailer.subject', locale: @locale))
    end
  end
end
