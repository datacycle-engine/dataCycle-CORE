# frozen_string_literal: true

module DataCycleCore
  class ReleasableSubscriptionMailer < ApplicationMailer
    def notify(user, content_ids)
      @user = user
      @contents = DataCycleCore::Thing.where(id: content_ids)

      mail(to: @user.email, subject: t('common.abo_finalized_title', count: @contents.size, locale: @user.ui_locale))
    end
  end
end
