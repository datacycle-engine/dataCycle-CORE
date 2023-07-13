# frozen_string_literal: true

module DataCycleCore
  class UserApiMailer < ApplicationMailer
    def notify(emails, new_user, user_attributes = {})
      return if emails.blank?

      @new_user = new_user
      @new_user.attributes = user_attributes
      @new_user.user_api_feature.current_issuer = @new_user.issuer
      @resource = @new_user
      @locale = DataCycleCore.ui_locales.first
      subject = first_available_i18n_t('feature.user_api.mailer.?.subject', @resource.template_namespaces, locale: @locale)

      mail(to: emails, subject: subject, template_name: first_existing_action_template(@resource.template_namespaces))
    end

    def notify_confirmed(user, user_attributes = {})
      return if user.blank? || user.email.blank?

      @new_user = user
      @new_user.attributes = user_attributes
      @new_user.user_api_feature.current_issuer = @new_user.issuer
      @resource = @new_user
      @locale = @new_user.ui_locale
      subject = first_available_i18n_t('feature.user_api.mailer.?.unlocked_subject', @resource.template_namespaces, locale: @locale)

      mail(to: @new_user.email, subject: subject, template_name: first_existing_action_template(@resource.template_namespaces))
    end
  end
end
