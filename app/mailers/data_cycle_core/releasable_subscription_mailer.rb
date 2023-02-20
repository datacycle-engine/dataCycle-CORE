# frozen_string_literal: true

module DataCycleCore
  class ReleasableSubscriptionMailer < ApplicationMailer
    def notify(user, content_ids)
      @user = user
      @contents = DataCycleCore::Thing.where(id: content_ids)
      @locale = @user.ui_locale

      mail(to: @user.email, subject: t('common.abo_finalized_title', count: @contents.size, locale: @locale))
    end

    def remind_receiver(user, data_link_ids)
      @user = user
      @data_links = DataCycleCore::DataLink.preload(:item).where(id: data_link_ids)
      @locale = @user.ui_locale

      mail(to: @user.email, subject: t('feature.releasable.mailer.remind_receiver.subject', count: @data_links.size, locale: @locale))
    end
  end
end
