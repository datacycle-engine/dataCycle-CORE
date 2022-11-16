# frozen_string_literal: true

module DataCycleCore
  class UserApiMailer < ApplicationMailer
    def notify(emails, new_user, current_issuer = nil)
      return if emails.blank?

      @new_user = new_user
      @new_user.user_api_feature.current_issuer = current_issuer
      @current_issuer = current_issuer
      @resource = @new_user
      @locale = DataCycleCore.ui_locales.first

      mail(to: emails, subject: t('feature.user_api.mailer.subject', locale: @locale))
    end

    def notify_confirmed(user, current_issuer = nil)
      return if user.blank? || user.email.blank?

      @new_user = user
      @new_user.user_api_feature.current_issuer = current_issuer
      @current_issuer = current_issuer
      @resource = @new_user
      @locale = @new_user.ui_locale

      mail(to: @new_user.email, subject: t('feature.user_api.mailer.unlocked_subject', locale: @locale))
    end
  end
end
