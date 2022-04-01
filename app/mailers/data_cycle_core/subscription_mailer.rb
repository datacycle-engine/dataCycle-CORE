# frozen_string_literal: true

module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    def notify(user, contents)
      @user = user
      @contents = contents
      mail(to: @user.email, subject: t('common.abo_changed_title', count: @contents.size, title: @contents.size == 1 ? I18n.with_locale(@contents.first.first_available_locale) { @contents.first.try(:title) } : nil, locale: @user.ui_locale))
    end
  end
end
