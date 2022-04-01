# frozen_string_literal: true

module DataCycleCore
  class ReleasableSubscriptionMailer < ApplicationMailer
    def notify(user, contents)
      @user = user
      @contents = contents

      mail(to: @user.email, subject: t('common.abo_finalized_title', count: @contents.size, locale: @user.ui_locale))
    end
  end
end
