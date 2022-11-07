# frozen_string_literal: true

module DataCycleCore
  class ReleasableSubscriptionMailer < ApplicationMailer
    def notify(user, content_ids)
      @user = user
      @contents = DataCycleCore::Thing.where(id: content_ids)
      @locale = @user.ui_locale

      mail(to: @user.email, subject: t('common.abo_finalized_title', count: @contents.size, locale: @locale))
    end
  end
end
