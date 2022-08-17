# frozen_string_literal: true

module DataCycleCore
  class SubscriptionMailer < ApplicationMailer
    self.delivery_job = DataCycleCore::SubscriptionMailerJob

    def notify(user, content_ids)
      @user = user
      @contents = DataCycleCore::Thing.where(id: content_ids)
      mail(to: @user.email, subject: t('common.abo_changed_title', count: @contents.size, title: @contents.size == 1 ? I18n.with_locale(@contents.first.first_available_locale) { @contents.first.try(:title) } : nil, locale: @user.ui_locale))
    end

    def notify_changed_watch_list_items(user, changed_items)
      @user = user
      @changed_items = changed_items
      @watch_lists = DataCycleCore::WatchList.where(id: @changed_items.keys).index_by(&:id)
      @users = DataCycleCore::User.where(id: @changed_items.values.flatten.pluck(:user_id)).index_by(&:id)
      @contents = DataCycleCore::Thing.where(id: @changed_items.values.flatten.pluck(:id)).index_by(&:id)

      mail(to: @user.email, subject: t('data_cycle_core.watch_list.mailer.subject', count: @watch_lists.size, type: DataCycleCore::WatchList.model_name.human(locale: @user.ui_locale, count: @watch_lists.size), locale: @user.ui_locale))
    end
  end
end
