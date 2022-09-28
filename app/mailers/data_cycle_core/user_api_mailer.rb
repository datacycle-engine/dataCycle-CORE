# frozen_string_literal: true

module DataCycleCore
  class UserApiMailer < ApplicationMailer
    def notify(emails, new_user, current_issuer = nil)
      return if emails.blank?

      @new_user = new_user
      @new_user.user_api_feature.current_issuer = current_issuer
      @locale = DataCycleCore.ui_locales.first

      mail(to: emails, subject: t('feature.user_api.mailer.subject', locale: @locale), from: @new_user.user_api_feature.user_mailer_from)
    end
  end
end
