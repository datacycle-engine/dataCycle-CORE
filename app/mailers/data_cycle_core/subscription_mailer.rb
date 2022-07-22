# frozen_string_literal: true

module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    def notify(user, content_ids)
      @user = user
      @contents = DataCycleCore::Thing.where(id: content_ids)
      mail(to: @user.email, subject: t('common.abo_changed_title', count: @contents.size, title: @contents.size == 1 ? I18n.with_locale(@contents.first.first_available_locale) { @contents.first.try(:title) } : nil, locale: @user.ui_locale))
    end

    def notify_changed_watch_list_items(user, watch_list, content_ids, type)
      @user = user
      @watch_list = watch_list
      @contents = DataCycleCore::Thing.where(id: content_ids)
      @type = type

      mail(to: @user.email, subject: t("data_cycle_core.watch_list.mailer.#{@type}.subject", count: @contents.size, type: @watch_list.model_name.human(locale: @user.ui_locale, count: 1), name: @watch_list.name, locale: @user.ui_locale))
    end
  end
end
